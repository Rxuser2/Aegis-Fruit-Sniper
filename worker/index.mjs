import { DurableObject } from "cloudflare:workers";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Aegis-Key",
  "Access-Control-Max-Age": "86400",
};

const INSTANCE_PERSIST_INTERVAL_MS = 45_000;
const LOCK_PERSIST_INTERVAL_MS = 150_000;
const ALARM_FLUSH_DELAY_MS = 55_000;
const HYDRATE_RETRY_INTERVAL_MS = 60_000;
const MAX_CATCH_HISTORY = 150;

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...CORS_HEADERS,
    },
  });
}

function safeParseJson(raw, fallback) {
  if (typeof raw !== "string" || raw.trim() === "") return fallback;
  try {
    const parsed = JSON.parse(raw);
    if (fallback && typeof fallback === "object" && !Array.isArray(fallback) && Array.isArray(parsed)) {
      return fallback;
    }
    return parsed ?? fallback;
  } catch {
    return fallback;
  }
}

function normalizeMapObject(val) {
  if (!val || typeof val !== "object" || Array.isArray(val)) return {};
  return val;
}

function normalizeInventorySnapshot(rawInv, fallbackUpdatedAt) {
  const inv = normalizeMapObject(rawInv);
  return {
    stored: Array.isArray(inv.stored) ? inv.stored.slice(0, 60) : [],
    held: Array.isArray(inv.held) ? inv.held.slice(0, 12) : [],
    totalStoredCount: Number(inv.totalStoredCount || 0),
    totalUnique: Number(inv.totalUnique || 0),
    totalValue: Number(inv.totalValue || 0),
    updatedAt: Number(inv.updatedAt || fallbackUpdatedAt),
  };
}

async function verifyAccessKey(request, expectedKey) {
  if (!expectedKey || typeof expectedKey !== "string") return false;
  let provided = request.headers.get("X-Aegis-Key") || "";
  if (!provided) {
    const auth = request.headers.get("Authorization") || "";
    if (auth.toLowerCase().startsWith("bearer ")) {
      provided = auth.slice(7).trim();
    }
  }
  if (!provided) return false;

  const encoder = new TextEncoder();
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expectedKey)),
  ]);
  return crypto.subtle.timingSafeEqual(providedHash, expectedHash);
}

export class AegisHubDO extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx = ctx;
    this.sql = ctx.storage.sql;

    // Hot in-memory actor state: prevents repeated SQLite scans on polling & syncs.
    this.instances = new Map();
    this.serverLocks = new Map();
    this.commands = new Map();
    this.fingerprints = new Map();
    this.fpMaxTs = 0;
    this.catchHistory = [];
    this.catchUids = new Set();
    this.globalConfig = { version: 0, config: {}, updatedAt: 0 };

    // Persistence / quota recovery bookkeeping
    this.schemaReady = false;
    this.hydrated = false;
    this.lastHydrateAttemptAt = 0;
    this.lastHydrateError = null;
    this.dirtyInstances = new Set();
    this.dirtyLocks = new Set();
    this.pendingFpWrites = new Set();
    this.pendingCatchesWrite = [];
    this.pendingGlobalConfigWrite = false;
    this.alarmPending = false;
    this.syntheticCatchId = 1;

    ctx.blockConcurrencyWhile(async () => {
      this.initAndHydrate(true);
    });
  }

  ensureSchema() {
    if (this.schemaReady) return;
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS instances (
        instance_key TEXT PRIMARY KEY,
        player_name TEXT NOT NULL DEFAULT '',
        display_name TEXT NOT NULL DEFAULT '',
        user_id TEXT NOT NULL DEFAULT '',
        level INTEGER NOT NULL DEFAULT 0,
        beli INTEGER NOT NULL DEFAULT 0,
        equipped_fruit TEXT NOT NULL DEFAULT '',
        place_id INTEGER NOT NULL DEFAULT 0,
        job_id TEXT NOT NULL DEFAULT '',
        players_count INTEGER NOT NULL DEFAULT 0,
        max_players INTEGER NOT NULL DEFAULT 12,
        status TEXT NOT NULL DEFAULT 'IDLE',
        flight_target TEXT NOT NULL DEFAULT '',
        map_fruits_json TEXT NOT NULL DEFAULT '[]',
        dealer_stock_json TEXT NOT NULL DEFAULT '[]',
        stored_session INTEGER NOT NULL DEFAULT 0,
        pool_count INTEGER NOT NULL DEFAULT 0,
        learned_count INTEGER NOT NULL DEFAULT 0,
        webhook_sent INTEGER NOT NULL DEFAULT 0,
        turbo_mode INTEGER NOT NULL DEFAULT 1,
        active_config_json TEXT NOT NULL DEFAULT '{}',
        override_config_json TEXT NOT NULL DEFAULT '{}',
        override_version INTEGER NOT NULL DEFAULT 0,
        last_seen INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL DEFAULT 0,
        inventory_json TEXT NOT NULL DEFAULT '{}'
      );
    `);
    try { this.sql.exec("ALTER TABLE instances ADD COLUMN started_at INTEGER NOT NULL DEFAULT 0"); } catch {}
    try { this.sql.exec("ALTER TABLE instances ADD COLUMN inventory_json TEXT NOT NULL DEFAULT '{}'"); } catch {}
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS meta_kv (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS commands (
        id TEXT PRIMARY KEY,
        target_key TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        consumed_by_json TEXT NOT NULL DEFAULT '{}'
      );

      CREATE TABLE IF NOT EXISTS fingerprints (
        asset_key TEXT PRIMARY KEY,
        fruit_id TEXT NOT NULL,
        learned_by TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS server_locks (
        job_id TEXT PRIMARY KEY,
        place_id INTEGER NOT NULL DEFAULT 0,
        instance_key TEXT NOT NULL,
        player_name TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL DEFAULT 'occupied',
        locked_until INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS catch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        catch_uid TEXT UNIQUE,
        instance_key TEXT NOT NULL,
        player_name TEXT NOT NULL,
        fruit_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        rarity TEXT NOT NULL,
        icon_url TEXT NOT NULL DEFAULT '',
        job_id TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'Map',
        created_at INTEGER NOT NULL
      );
    `);
    this.schemaReady = true;
  }

  initAndHydrate(force = false) {
    const now = Date.now();
    if (this.hydrated) return true;
    if (!force && now - this.lastHydrateAttemptAt < HYDRATE_RETRY_INTERVAL_MS) {
      return false;
    }
    this.lastHydrateAttemptAt = now;

    try {
      this.ensureSchema();

      // Snapshot any in-memory buffers accumulated during degraded quota recovery
      const bufferedInstances = new Map(this.instances);
      const bufferedLocks = new Map(this.serverLocks);
      const bufferedCommands = new Map(this.commands);
      const bufferedFpKeys = Array.from(this.pendingFpWrites);
      const bufferedFps = bufferedFpKeys.map((k) => this.fingerprints.get(k)).filter(Boolean);
      const bufferedCatches = [...this.pendingCatchesWrite];
      const bufferedGlobal = this.pendingGlobalConfigWrite ? { ...this.globalConfig } : null;

      // Load tables once into local structures before mutating instance state
      const dbInstances = new Map();
      for (const r of this.sql.exec("SELECT * FROM instances").toArray()) {
        dbInstances.set(r.instance_key, {
          instanceKey: r.instance_key,
          playerName: r.player_name,
          displayName: r.display_name,
          userId: r.user_id,
          level: Number(r.level || 0),
          beli: Number(r.beli || 0),
          equippedFruit: r.equipped_fruit || "None",
          placeId: Number(r.place_id || 0),
          jobId: r.job_id || "",
          playersCount: Number(r.players_count || 0),
          maxPlayers: Number(r.max_players || 12),
          status: r.status || "IDLE",
          flightTarget: r.flight_target || "",
          mapFruits: safeParseJson(r.map_fruits_json, []),
          dealerStock: safeParseJson(r.dealer_stock_json, []),
          storedSession: Number(r.stored_session || 0),
          poolCount: Number(r.pool_count || 0),
          learnedCount: Number(r.learned_count || 0),
          webhookSent: Number(r.webhook_sent || 0),
          turboMode: r.turbo_mode === 1,
          activeConfig: safeParseJson(r.active_config_json, {}),
          overrideConfig: safeParseJson(r.override_config_json, {}),
          overrideVersion: Number(r.override_version || 0),
          lastSeen: Number(r.last_seen || 0),
          startedAt: Number(r.started_at || r.last_seen || now),
          inventory: safeParseJson(r.inventory_json, { stored: [], held: [], totalStoredCount: 0, totalUnique: 0, totalValue: 0 }),
          lastPersistedAt: now,
        });
      }

      const metaRow = this.sql.exec("SELECT v, updated_at FROM meta_kv WHERE k = 'global_config'").toArray()[0];
      const dbGlobal = metaRow
        ? { version: 0, config: {}, ...safeParseJson(metaRow.v, {}), updatedAt: Number(metaRow.updated_at || 0) }
        : { version: 0, config: {}, updatedAt: 0 };

      const dbCommands = new Map();
      const expiredCmdIds = [];
      for (const c of this.sql.exec("SELECT id, target_key, action, payload_json, created_at, consumed_by_json FROM commands").toArray()) {
        if (Number(c.created_at || 0) < now - 120_000) {
          expiredCmdIds.push(c.id);
          continue;
        }
        dbCommands.set(c.id, {
          id: c.id,
          targetKey: c.target_key,
          action: c.action,
          payload: safeParseJson(c.payload_json, {}),
          createdAt: Number(c.created_at || now),
          consumedBy: safeParseJson(c.consumed_by_json, {}),
        });
      }

      const dbLocks = new Map();
      const expiredLockJobIds = [];
      for (const l of this.sql.exec("SELECT job_id, place_id, instance_key, player_name, reason, locked_until FROM server_locks").toArray()) {
        if (Number(l.locked_until || 0) <= now) {
          expiredLockJobIds.push(l.job_id);
          continue;
        }
        dbLocks.set(l.job_id, {
          job_id: l.job_id,
          place_id: Number(l.place_id || 0),
          instance_key: l.instance_key,
          player_name: l.player_name || "",
          reason: l.reason || "occupied",
          locked_until: Number(l.locked_until || 0),
          lastPersistedAt: now,
        });
      }

      const dbFingerprints = new Map();
      let dbMaxFpTs = 0;
      for (const fp of this.sql.exec("SELECT asset_key, fruit_id, learned_by, updated_at FROM fingerprints").toArray()) {
        const ts = Number(fp.updated_at || 0);
        if (ts > dbMaxFpTs) dbMaxFpTs = ts;
        dbFingerprints.set(fp.asset_key, {
          asset_key: fp.asset_key,
          fruit_id: fp.fruit_id,
          learned_by: fp.learned_by || "",
          updated_at: ts,
        });
      }

      const dbCatches = [];
      const dbCatchUids = new Set();
      let maxCatchId = 0;
      for (const ch of this.sql
        .exec(
          "SELECT id, catch_uid, instance_key, player_name, fruit_id, display_name, rarity, icon_url, job_id, source, created_at FROM catch_history ORDER BY id DESC LIMIT ?",
          MAX_CATCH_HISTORY
        )
        .toArray()) {
        if (Number(ch.id || 0) > maxCatchId) maxCatchId = Number(ch.id || 0);
        if (ch.catch_uid) dbCatchUids.add(ch.catch_uid);
        dbCatches.push({
          id: ch.id,
          catch_uid: ch.catch_uid,
          instance_key: ch.instance_key,
          player_name: ch.player_name,
          fruit_id: ch.fruit_id,
          display_name: ch.display_name,
          rarity: ch.rarity,
          icon_url: ch.icon_url || "",
          job_id: ch.job_id || "",
          source: ch.source || "Map",
          created_at: Number(ch.created_at || 0),
        });
      }

      this.instances = dbInstances;
      this.globalConfig = dbGlobal;
      this.commands = dbCommands;
      this.serverLocks = dbLocks;
      this.fingerprints = dbFingerprints;
      this.fpMaxTs = dbMaxFpTs;
      this.catchHistory = dbCatches;
      this.catchUids = dbCatchUids;
      this.syntheticCatchId = Math.max(this.syntheticCatchId, maxCatchId + 1);
      this.hydrated = true;
      this.lastHydrateError = null;

      // Prune expired records discovered during cold hydration by primary key
      for (const cmdId of expiredCmdIds) {
        this.sql.exec("DELETE FROM commands WHERE id = ?", cmdId);
      }
      for (const jobId of expiredLockJobIds) {
        this.sql.exec("DELETE FROM server_locks WHERE job_id = ?", jobId);
      }

      // Replay any buffered updates collected while waiting for quota reset
      if (bufferedGlobal && (bufferedGlobal.version > (this.globalConfig.version || 0) || Object.keys(this.globalConfig.config || {}).length === 0)) {
        const nextVer = Math.max(Number(this.globalConfig.version || 0) + 1, Number(bufferedGlobal.version || 1));
        this.globalConfig = { ...bufferedGlobal, version: nextVer };
        this.persistGlobalConfig(now);
      }
      this.pendingGlobalConfigWrite = false;

      for (const [k, bufInst] of bufferedInstances) {
        const existing = this.instances.get(k);
        const merged = {
          ...bufInst,
          overrideConfig: existing ? existing.overrideConfig : bufInst.overrideConfig,
          overrideVersion: existing ? Math.max(existing.overrideVersion || 0, bufInst.overrideVersion || 0) : bufInst.overrideVersion,
          startedAt: existing?.startedAt && bufInst.lastSeen - (existing.lastSeen || 0) <= 180_000
            ? Math.min(existing.startedAt, bufInst.startedAt || existing.startedAt)
            : bufInst.startedAt,
          hasPendingOverride: false,
        };
        if (bufInst.hasPendingOverride) {
          merged.overrideConfig = bufInst.overrideConfig;
          merged.overrideVersion = Number(existing?.overrideVersion || 0) + 1;
        }
        this.instances.set(k, merged);
        this.persistInstanceRow(merged, now);
      }

      for (const [jid, bufLock] of bufferedLocks) {
        if (bufLock.locked_until > now) {
          this.serverLocks.set(jid, bufLock);
          this.persistLockRow(bufLock, now);
        }
      }

      for (const cmd of bufferedCommands.values()) {
        if (!this.commands.has(cmd.id) && cmd.createdAt >= now - 120_000) {
          this.commands.set(cmd.id, cmd);
          this.persistCommandRow(cmd);
        }
      }

      for (const fp of bufferedFps) {
        const existing = this.fingerprints.get(fp.asset_key);
        let fruitId = fp.fruit_id;
        if (existing) {
          if (existing.fruit_id === "__SHARED__" || existing.fruit_id === fruitId) continue;
          fruitId = "__SHARED__";
        }
        const mergedFp = { ...fp, fruit_id: fruitId };
        this.fingerprints.set(fp.asset_key, mergedFp);
        if (mergedFp.updated_at > this.fpMaxTs) this.fpMaxTs = mergedFp.updated_at;
        this.persistFingerprintRow(mergedFp);
      }
      this.pendingFpWrites.clear();

      for (const c of bufferedCatches) {
        if (!this.catchUids.has(c.catch_uid)) {
          this.persistCatchRow(c);
          this.catchUids.add(c.catch_uid);
          this.catchHistory.unshift(c);
        }
      }
      if (this.catchHistory.length > MAX_CATCH_HISTORY) {
        this.catchHistory.sort((a, b) => (b.id || 0) - (a.id || 0));
        this.catchHistory.length = MAX_CATCH_HISTORY;
      }
      this.pendingCatchesWrite = [];

      return true;
    } catch (err) {
      this.hydrated = false;
      this.lastHydrateError = err instanceof Error ? err.message : String(err);
      return false;
    }
  }

  trySql(fn) {
    if (!this.hydrated) return false;
    try {
      fn();
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.lastHydrateError = msg;
      return false;
    }
  }

  persistGlobalConfig(now) {
    return this.trySql(() => {
      this.sql.exec(
        "INSERT INTO meta_kv (k, v, updated_at) VALUES (?, ?, ?) ON CONFLICT(k) DO UPDATE SET v = excluded.v, updated_at = excluded.updated_at",
        "global_config",
        JSON.stringify(this.globalConfig),
        now
      );
    });
  }

  persistInstanceRow(inst, now) {
    const ok = this.trySql(() => {
      this.sql.exec(
        `INSERT INTO instances (
           instance_key, player_name, display_name, user_id, level, beli, equipped_fruit,
           place_id, job_id, players_count, max_players, status, flight_target,
           map_fruits_json, dealer_stock_json, stored_session, pool_count, learned_count,
           webhook_sent, turbo_mode, active_config_json, override_config_json, override_version,
           last_seen, started_at, inventory_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(instance_key) DO UPDATE SET
           player_name = excluded.player_name,
           display_name = excluded.display_name,
           user_id = excluded.user_id,
           level = excluded.level,
           beli = excluded.beli,
           equipped_fruit = excluded.equipped_fruit,
           place_id = excluded.place_id,
           job_id = excluded.job_id,
           players_count = excluded.players_count,
           max_players = excluded.max_players,
           status = excluded.status,
           flight_target = excluded.flight_target,
           map_fruits_json = excluded.map_fruits_json,
           dealer_stock_json = excluded.dealer_stock_json,
           stored_session = excluded.stored_session,
           pool_count = excluded.pool_count,
           learned_count = excluded.learned_count,
           webhook_sent = excluded.webhook_sent,
           turbo_mode = excluded.turbo_mode,
           active_config_json = excluded.active_config_json,
           override_config_json = excluded.override_config_json,
           override_version = excluded.override_version,
           last_seen = excluded.last_seen,
           started_at = excluded.started_at,
           inventory_json = excluded.inventory_json`,
        inst.instanceKey,
        inst.playerName,
        inst.displayName,
        inst.userId,
        inst.level,
        inst.beli,
        inst.equippedFruit,
        inst.placeId,
        inst.jobId,
        inst.playersCount,
        inst.maxPlayers,
        inst.status,
        inst.flightTarget,
        JSON.stringify(inst.mapFruits || []),
        JSON.stringify(inst.dealerStock || []),
        inst.storedSession,
        inst.poolCount,
        inst.learnedCount,
        inst.webhookSent,
        inst.turboMode ? 1 : 0,
        JSON.stringify(inst.activeConfig || {}),
        JSON.stringify(inst.overrideConfig || {}),
        inst.overrideVersion || 0,
        inst.lastSeen,
        inst.startedAt,
        JSON.stringify(inst.inventory || {})
      );
    });
    if (ok) {
      inst.lastPersistedAt = now;
      this.dirtyInstances.delete(inst.instanceKey);
    }
    return ok;
  }

  persistLockRow(lock, now) {
    const ok = this.trySql(() => {
      this.sql.exec(
        `INSERT INTO server_locks (job_id, place_id, instance_key, player_name, reason, locked_until)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(job_id) DO UPDATE SET
           place_id = excluded.place_id,
           instance_key = excluded.instance_key,
           player_name = excluded.player_name,
           reason = excluded.reason,
           locked_until = excluded.locked_until`,
        lock.job_id,
        lock.place_id,
        lock.instance_key,
        lock.player_name,
        lock.reason,
        lock.locked_until
      );
    });
    if (ok) {
      lock.lastPersistedAt = now;
      this.dirtyLocks.delete(lock.job_id);
    }
    return ok;
  }

  persistFingerprintRow(fp) {
    return this.trySql(() => {
      this.sql.exec(
        `INSERT INTO fingerprints (asset_key, fruit_id, learned_by, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(asset_key) DO UPDATE SET fruit_id = excluded.fruit_id, learned_by = excluded.learned_by, updated_at = excluded.updated_at`,
        fp.asset_key,
        fp.fruit_id,
        fp.learned_by,
        fp.updated_at
      );
    });
  }

  persistCommandRow(cmd) {
    return this.trySql(() => {
      this.sql.exec(
        "INSERT OR REPLACE INTO commands (id, target_key, action, payload_json, created_at, consumed_by_json) VALUES (?, ?, ?, ?, ?, ?)",
        cmd.id,
        cmd.targetKey,
        cmd.action,
        JSON.stringify(cmd.payload || {}),
        cmd.createdAt,
        JSON.stringify(cmd.consumedBy || {})
      );
    });
  }

  persistCatchRow(catchRow) {
    return this.trySql(() => {
      const inserted = this.sql
        .exec(
          `INSERT OR IGNORE INTO catch_history (catch_uid, instance_key, player_name, fruit_id, display_name, rarity, icon_url, job_id, source, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           RETURNING id`,
          catchRow.catch_uid,
          catchRow.instance_key,
          catchRow.player_name,
          catchRow.fruit_id,
          catchRow.display_name,
          catchRow.rarity,
          catchRow.icon_url,
          catchRow.job_id,
          catchRow.source,
          catchRow.created_at
        )
        .toArray()[0];
      if (inserted?.id) {
        catchRow.id = inserted.id;
      }
    });
  }

  scheduleFlushAlarm(now) {
    if (!this.hydrated || this.alarmPending) return;
    if (this.dirtyInstances.size === 0 && this.dirtyLocks.size === 0) return;
    this.alarmPending = true;
    try {
      void this.ctx.storage.setAlarm(now + ALARM_FLUSH_DELAY_MS);
    } catch {
      this.alarmPending = false;
    }
  }

  pruneExpiredLocksInMemory(now) {
    const expired = [];
    for (const [jid, lock] of this.serverLocks) {
      if (lock.locked_until <= now) {
        this.serverLocks.delete(jid);
        this.dirtyLocks.delete(jid);
        expired.push(jid);
      }
    }
    if (expired.length > 0 && this.hydrated) {
      this.trySql(() => {
        for (const jid of expired) {
          this.sql.exec("DELETE FROM server_locks WHERE job_id = ?", jid);
        }
      });
    }
  }

  async alarm() {
    this.alarmPending = false;
    const now = Date.now();
    if (!this.hydrated) {
      this.initAndHydrate(true);
    }
    this.pruneExpiredLocksInMemory(now);

    if (!this.hydrated) return;

    for (const key of Array.from(this.dirtyInstances)) {
      const inst = this.instances.get(key);
      if (inst) {
        this.persistInstanceRow(inst, now);
      } else {
        this.dirtyInstances.delete(key);
      }
    }
    for (const jid of Array.from(this.dirtyLocks)) {
      const lock = this.serverLocks.get(jid);
      if (lock && lock.locked_until > now) {
        this.persistLockRow(lock, now);
      } else {
        this.dirtyLocks.delete(jid);
      }
    }
  }

  async syncInstance(payload) {
    const now = Date.now();
    this.initAndHydrate(false);

    const instanceKey = String(payload.instanceKey || payload.userId || payload.playerName || "").trim();
    if (!instanceKey) {
      throw new Error("Missing instanceKey or userId");
    }

    const playerName = String(payload.playerName || instanceKey);
    const displayName = String(payload.displayName || playerName);
    const userId = String(payload.userId || instanceKey);
    const placeId = Number(payload.placeId || 0);
    const jobId = String(payload.jobId || "").trim();
    const level = Number(payload.level || 0);
    const beli = Number(payload.beli || 0);
    const equippedFruit = String(payload.equippedFruit || "None");
    const storedSession = Number(payload.storedSession || 0);

    const prevInst = this.instances.get(instanceKey);

    // If instance hopped away from an old server, mark old server as checked (5 min cross-account cooldown)
    if (prevInst?.jobId && prevInst.jobId !== jobId) {
      const checkedLock = {
        job_id: prevInst.jobId,
        place_id: placeId,
        instance_key: instanceKey,
        player_name: playerName,
        reason: "checked",
        locked_until: now + 300_000,
        lastPersistedAt: 0,
      };
      this.serverLocks.set(prevInst.jobId, checkedLock);
      this.persistLockRow(checkedLock, now);
    }

    // Keep active server locked as occupied for 6 minutes; persist at most every 2.5 minutes unless changed
    if (jobId) {
      const prevLock = this.serverLocks.get(jobId);
      const lockChanged = !prevLock || prevLock.instance_key !== instanceKey || prevLock.reason !== "occupied" || prevLock.place_id !== placeId;
      const occLock = {
        job_id: jobId,
        place_id: placeId,
        instance_key: instanceKey,
        player_name: playerName,
        reason: "occupied",
        locked_until: now + 360_000,
        lastPersistedAt: prevLock?.lastPersistedAt || 0,
      };
      this.serverLocks.set(jobId, occLock);
      if (lockChanged || now - occLock.lastPersistedAt >= LOCK_PERSIST_INTERVAL_MS) {
        this.persistLockRow(occLock, now);
      } else {
        this.dirtyLocks.add(jobId);
      }
    }

    this.pruneExpiredLocksInMemory(now);

    // Resolve continuous running start timestamp across server hops
    const rawStartedAt = Number(payload.startedAt || 0);
    let startedAt = now;
    if (rawStartedAt > 0 && rawStartedAt <= now + 60_000) {
      startedAt = rawStartedAt;
    } else if (prevInst?.startedAt > 0 && now - (prevInst.lastSeen || 0) <= 180_000) {
      startedAt = prevInst.startedAt;
    }

    const invSnapshot = normalizeInventorySnapshot(payload.inventory, now);
    const activeCfg = normalizeMapObject(payload.activeConfig);
    const nextInst = {
      instanceKey,
      playerName,
      displayName,
      userId,
      level,
      beli,
      equippedFruit,
      placeId,
      jobId,
      playersCount: Number(payload.playersCount || 0),
      maxPlayers: Number(payload.maxPlayers || 12),
      status: String(payload.status || "IDLE"),
      flightTarget: String(payload.flightTarget || ""),
      mapFruits: Array.isArray(payload.mapFruits) ? payload.mapFruits.slice(0, 12) : [],
      dealerStock: Array.isArray(payload.dealerStock) ? payload.dealerStock.slice(0, 20) : [],
      storedSession,
      poolCount: Number(payload.poolCount || 0),
      learnedCount: Number(payload.learnedCount || 0),
      webhookSent: Number(payload.webhookSent || 0),
      turboMode: payload.turboMode === true,
      activeConfig: activeCfg,
      overrideConfig: prevInst ? prevInst.overrideConfig : {},
      overrideVersion: prevInst ? Number(prevInst.overrideVersion || 0) : 0,
      lastSeen: now,
      startedAt,
      inventory: invSnapshot,
      lastPersistedAt: prevInst?.lastPersistedAt || 0,
    };
    this.instances.set(instanceKey, nextInst);

    const importantChange =
      !prevInst ||
      prevInst.jobId !== jobId ||
      prevInst.level !== level ||
      prevInst.equippedFruit !== equippedFruit ||
      prevInst.storedSession !== storedSession ||
      prevInst.startedAt !== startedAt;

    if (importantChange || now - nextInst.lastPersistedAt >= INSTANCE_PERSIST_INTERVAL_MS) {
      this.persistInstanceRow(nextInst, now);
    } else {
      this.dirtyInstances.add(instanceKey);
    }

    // Merge newly learned composite fingerprints in RAM with collision protection (0 SQLite reads)
    const newFps = normalizeMapObject(payload.newFingerprints);
    let uploadedFpCount = 0;
    for (const [assetKey, rawFruitId] of Object.entries(newFps)) {
      if (typeof assetKey !== "string" || typeof rawFruitId !== "string" || !assetKey || !rawFruitId) continue;
      if (!assetKey.startsWith("SIG:") && !assetKey.startsWith("SIGMESH:") && !assetKey.startsWith("SIGASSET:")) {
        continue;
      }
      const existing = this.fingerprints.get(assetKey);
      let targetFruitId = rawFruitId;
      if (existing) {
        if (existing.fruit_id === "__SHARED__" || existing.fruit_id === rawFruitId) continue;
        targetFruitId = "__SHARED__";
      }
      const fpEntry = {
        asset_key: assetKey,
        fruit_id: targetFruitId,
        learned_by: playerName,
        updated_at: now,
      };
      this.fingerprints.set(assetKey, fpEntry);
      if (now > this.fpMaxTs) this.fpMaxTs = now;
      if (!this.persistFingerprintRow(fpEntry)) {
        this.pendingFpWrites.add(assetKey);
      }
      uploadedFpCount += 1;
    }

    // Record newly caught/stored fruits (deduped in RAM first)
    if (Array.isArray(payload.catches) && payload.catches.length > 0) {
      let insertedAny = false;
      for (const c of payload.catches.slice(0, 15)) {
        if (!c || typeof c !== "object" || !c.fruitId) continue;
        const uid = String(c.catchUid || `${instanceKey}:${c.fruitId}:${c.ts || now}`);
        if (this.catchUids.has(uid)) continue;

        const row = {
          id: this.syntheticCatchId++,
          catch_uid: uid,
          instance_key: instanceKey,
          player_name: playerName,
          fruit_id: String(c.fruitId),
          display_name: String(c.displayName || c.fruitId),
          rarity: String(c.rarity || "Unknown"),
          icon_url: String(c.iconUrl || ""),
          job_id: String(c.jobId || jobId),
          source: String(c.source || "Map"),
          created_at: Number(c.ts || now),
        };
        this.catchUids.add(uid);
        this.catchHistory.unshift(row);
        if (!this.persistCatchRow(row)) {
          this.pendingCatchesWrite.push(row);
        }
        insertedAny = true;
      }

      if (insertedAny && this.catchHistory.length > MAX_CATCH_HISTORY) {
        const dropped = this.catchHistory.splice(MAX_CATCH_HISTORY);
        for (const d of dropped) {
          if (d.catch_uid) this.catchUids.delete(d.catch_uid);
        }
        const oldestKept = this.catchHistory[this.catchHistory.length - 1];
        if (oldestKept?.id && typeof oldestKept.id === "number") {
          this.trySql(() => {
            this.sql.exec("DELETE FROM catch_history WHERE id < ?", oldestKept.id);
          });
        }
      }
    }

    const knownGlobalVersion = Number(payload.knownGlobalVersion || 0);
    const knownOverrideVersion = Number(payload.knownOverrideVersion || 0);

    // Pop pending commands from RAM (0 SQLite reads)
    const outCommands = [];
    for (const [cmdId, cmd] of Array.from(this.commands.entries())) {
      if (cmd.createdAt < now - 120_000) {
        this.commands.delete(cmdId);
        this.trySql(() => this.sql.exec("DELETE FROM commands WHERE id = ?", cmdId));
        continue;
      }
      if (cmd.targetKey !== instanceKey && cmd.targetKey !== "*") continue;

      if (cmd.targetKey === "*") {
        if (cmd.consumedBy[instanceKey]) continue;
        cmd.consumedBy[instanceKey] = now;
        this.trySql(() =>
          this.sql.exec("UPDATE commands SET consumed_by_json = ? WHERE id = ?", JSON.stringify(cmd.consumedBy), cmdId)
        );
      } else {
        this.commands.delete(cmdId);
        this.trySql(() => this.sql.exec("DELETE FROM commands WHERE id = ?", cmdId));
      }

      outCommands.push({
        id: cmd.id,
        action: cmd.action,
        payload: cmd.payload || {},
        createdAt: cmd.createdAt,
      });
    }
    outCommands.sort((a, b) => a.createdAt - b.createdAt);

    // Collect global blocked JobIds held by OTHER instances from RAM (0 SQLite reads)
    const otherLocks = [];
    for (const lock of this.serverLocks.values()) {
      if (lock.locked_until > now && lock.instance_key !== instanceKey) {
        otherLocks.push(lock);
      }
    }
    otherLocks.sort((a, b) => b.locked_until - a.locked_until);
    const blockedJobIds = otherLocks.slice(0, 300).map((l) => l.job_id);

    // Only serialize fingerprints when client's state differs from server's max_ts or total
    const fpTotal = this.fingerprints.size;
    const fpMaxTs = this.fpMaxTs;
    const knownFpTs = Number(payload.knownFpTs || 0);
    const knownFpTotal = Number(payload.knownFpTotal || -1);
    let globalFingerprints = null;
    if (knownFpTs !== fpMaxTs || knownFpTotal !== fpTotal || uploadedFpCount > 0) {
      globalFingerprints = {};
      for (const fp of this.fingerprints.values()) {
        globalFingerprints[fp.asset_key] = fp.fruit_id;
      }
    }

    this.scheduleFlushAlarm(now);

    return {
      ok: true,
      serverTime: now,
      globalConfigVersion: this.globalConfig.version || 0,
      globalConfig: (this.globalConfig.version || 0) !== knownGlobalVersion ? normalizeMapObject(this.globalConfig.config) : null,
      overrideVersion: nextInst.overrideVersion,
      overrideConfig: nextInst.overrideVersion !== knownOverrideVersion ? nextInst.overrideConfig : null,
      commands: outCommands,
      blockedJobIds,
      fpMaxTs,
      fpTotal,
      globalFingerprints,
    };
  }

  async claimServer(payload) {
    const now = Date.now();
    this.initAndHydrate(false);

    const instanceKey = String(payload.instanceKey || "").trim();
    const playerName = String(payload.playerName || instanceKey);
    const placeId = Number(payload.placeId || 0);
    const jobId = String(payload.jobId || "").trim();
    const oldJobId = String(payload.oldJobId || "").trim();

    if (!instanceKey || !jobId) {
      return { ok: false, error: "Missing instanceKey or jobId" };
    }

    if (oldJobId && oldJobId !== jobId) {
      const checkedLock = {
        job_id: oldJobId,
        place_id: placeId,
        instance_key: instanceKey,
        player_name: playerName,
        reason: "checked",
        locked_until: now + 300_000,
        lastPersistedAt: 0,
      };
      this.serverLocks.set(oldJobId, checkedLock);
      this.persistLockRow(checkedLock, now);
    }

    this.pruneExpiredLocksInMemory(now);

    const existing = this.serverLocks.get(jobId);
    if (existing && existing.instance_key !== instanceKey && existing.locked_until > now) {
      return {
        ok: false,
        claimedBy: existing.player_name || existing.instance_key,
        reason: existing.reason,
      };
    }

    const claimLock = {
      job_id: jobId,
      place_id: placeId,
      instance_key: instanceKey,
      player_name: playerName,
      reason: "claiming",
      locked_until: now + 120_000,
      lastPersistedAt: 0,
    };
    this.serverLocks.set(jobId, claimLock);
    this.persistLockRow(claimLock, now);

    return { ok: true, jobId };
  }

  async getDashboard() {
    const now = Date.now();
    this.initAndHydrate(false);
    this.pruneExpiredLocksInMemory(now);

    const instances = Array.from(this.instances.values())
      .sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0))
      .map((r) => ({
        instanceKey: r.instanceKey,
        playerName: r.playerName,
        displayName: r.displayName,
        userId: r.userId,
        level: r.level,
        beli: r.beli,
        equippedFruit: r.equippedFruit,
        placeId: r.placeId,
        jobId: r.jobId,
        playersCount: r.playersCount,
        maxPlayers: r.maxPlayers,
        status: r.status,
        flightTarget: r.flightTarget,
        mapFruits: r.mapFruits || [],
        dealerStock: r.dealerStock || [],
        storedSession: r.storedSession,
        poolCount: r.poolCount,
        learnedCount: r.learnedCount,
        webhookSent: r.webhookSent,
        turboMode: r.turboMode === true,
        activeConfig: r.activeConfig || {},
        overrideConfig: r.overrideConfig || {},
        overrideVersion: r.overrideVersion || 0,
        lastSeen: r.lastSeen,
        startedAt: r.startedAt || r.lastSeen || now,
        inventory: r.inventory || { stored: [], held: [], totalStoredCount: 0, totalUnique: 0, totalValue: 0 },
        online: now - (r.lastSeen || 0) < 20_000,
      }));

    const fpRows = Array.from(this.fingerprints.values())
      .sort((a, b) => (b.updated_at || 0) - (a.updated_at || 0))
      .slice(0, 250);

    const lockRows = Array.from(this.serverLocks.values())
      .filter((l) => l.locked_until > now)
      .sort((a, b) => b.locked_until - a.locked_until)
      .slice(0, 100)
      .map((l) => ({
        job_id: l.job_id,
        place_id: l.place_id,
        instance_key: l.instance_key,
        player_name: l.player_name,
        reason: l.reason,
        locked_until: l.locked_until,
      }));

    return {
      ok: true,
      serverTime: now,
      instances,
      globalConfig: this.globalConfig,
      catchHistory: this.catchHistory.slice(0, 60),
      fingerprintsTotal: this.fingerprints.size,
      fingerprints: fpRows,
      serverLocks: lockRows,
      cacheStatus: {
        hydrated: this.hydrated,
        quotaDegraded: !this.hydrated,
        lastError: this.lastHydrateError,
      },
    };
  }

  async setGlobalConfig(newConfig, merge = true) {
    const now = Date.now();
    this.initAndHydrate(false);

    const baseCfg = merge ? normalizeMapObject(this.globalConfig.config) : {};
    const incoming = normalizeMapObject(newConfig);
    const nextCfg = { ...baseCfg, ...incoming };
    this.globalConfig = {
      version: Number(this.globalConfig.version || 0) + 1,
      config: nextCfg,
      updatedAt: now,
    };
    if (!this.persistGlobalConfig(now)) {
      this.pendingGlobalConfigWrite = true;
    }
    return { ok: true, globalConfig: this.globalConfig };
  }

  async setInstanceOverride(instanceKey, overrideConfig, clear = false) {
    const now = Date.now();
    this.initAndHydrate(false);

    const inst = this.instances.get(instanceKey);
    if (!inst) {
      return { ok: false, error: "Instance not found" };
    }
    const nextVer = Number(inst.overrideVersion || 0) + 1;
    const prevObj = normalizeMapObject(inst.overrideConfig);
    const nextObj = clear ? {} : { ...prevObj, ...normalizeMapObject(overrideConfig) };
    for (const [k, v] of Object.entries(nextObj)) {
      if (v === null) delete nextObj[k];
    }
    inst.overrideConfig = nextObj;
    inst.overrideVersion = nextVer;

    if (!this.persistInstanceRow(inst, now)) {
      inst.hasPendingOverride = true;
      this.dirtyInstances.add(instanceKey);
    } else {
      inst.hasPendingOverride = false;
    }
    return { ok: true, instanceKey, overrideVersion: nextVer, overrideConfig: nextObj };
  }

  async enqueueCommand({ targetKey = "*", action, payload = {} }) {
    if (!action || typeof action !== "string") {
      return { ok: false, error: "Missing action" };
    }
    this.initAndHydrate(false);

    const now = Date.now();
    const id = crypto.randomUUID();
    const cmd = {
      id,
      targetKey: String(targetKey || "*"),
      action,
      payload: normalizeMapObject(payload),
      createdAt: now,
      consumedBy: {},
    };
    this.commands.set(id, cmd);
    this.persistCommandRow(cmd);
    return { ok: true, id, targetKey: cmd.targetKey, action };
  }

  async deleteInstance(instanceKey) {
    this.initAndHydrate(false);
    this.instances.delete(instanceKey);
    this.dirtyInstances.delete(instanceKey);

    const lockJobIds = [];
    for (const [jid, lock] of this.serverLocks) {
      if (lock.instance_key === instanceKey) {
        this.serverLocks.delete(jid);
        this.dirtyLocks.delete(jid);
        lockJobIds.push(jid);
      }
    }

    this.trySql(() => {
      this.sql.exec("DELETE FROM instances WHERE instance_key = ?", instanceKey);
      for (const jid of lockJobIds) {
        this.sql.exec("DELETE FROM server_locks WHERE job_id = ?", jid);
      }
    });
    return { ok: true };
  }

  async clearHistory() {
    this.initAndHydrate(false);
    this.catchHistory = [];
    this.catchUids.clear();
    this.pendingCatchesWrite = [];
    this.trySql(() => {
      this.sql.exec("DELETE FROM catch_history");
    });
    return { ok: true };
  }

  async deleteFingerprint(assetKey) {
    this.initAndHydrate(false);
    this.fingerprints.delete(assetKey);
    this.pendingFpWrites.delete(assetKey);
    let maxTs = 0;
    for (const fp of this.fingerprints.values()) {
      if ((fp.updated_at || 0) > maxTs) maxTs = fp.updated_at || 0;
    }
    this.fpMaxTs = maxTs;

    this.trySql(() => {
      this.sql.exec("DELETE FROM fingerprints WHERE asset_key = ?", assetKey);
    });
    return { ok: true };
  }

  async clearFingerprints(mode = "all") {
    this.initAndHydrate(false);
    if (mode === "legacy") {
      const removedKeys = [];
      for (const assetKey of this.fingerprints.keys()) {
        if (!assetKey.startsWith("SIG:") && !assetKey.startsWith("SIGMESH:") && !assetKey.startsWith("SIGASSET:")) {
          this.fingerprints.delete(assetKey);
          this.pendingFpWrites.delete(assetKey);
          removedKeys.push(assetKey);
        }
      }
      let maxTs = 0;
      for (const fp of this.fingerprints.values()) {
        if ((fp.updated_at || 0) > maxTs) maxTs = fp.updated_at || 0;
      }
      this.fpMaxTs = maxTs;
      this.trySql(() => {
        for (const k of removedKeys) {
          this.sql.exec("DELETE FROM fingerprints WHERE asset_key = ?", k);
        }
      });
    } else {
      this.fingerprints.clear();
      this.pendingFpWrites.clear();
      this.fpMaxTs = 0;
      this.trySql(() => {
        this.sql.exec("DELETE FROM fingerprints");
      });
    }
    return { ok: true, mode };
  }
}

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);

      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
      }

      if (url.pathname === "/api/health" && request.method === "GET") {
        return jsonResponse({ ok: true, service: "aegis-fruit-hub", version: "3.5" });
      }

      const authorized = await verifyAccessKey(request, env.AEGIS_ACCESS_KEY);
      if (!authorized) {
        return jsonResponse({ ok: false, error: "Unauthorized — invalid or missing Aegis Access Key" }, 401);
      }

      if (url.pathname === "/api/verify" && request.method === "GET") {
        return jsonResponse({ ok: true });
      }

      const stub = env.AEGIS_HUB.getByName("main");

      if (url.pathname === "/api/sync" && request.method === "POST") {
        const body = await request.json();
        return jsonResponse(await stub.syncInstance(body));
      }

      if (url.pathname === "/api/claim-server" && request.method === "POST") {
        const body = await request.json();
        return jsonResponse(await stub.claimServer(body));
      }

      if (url.pathname === "/api/dashboard" && request.method === "GET") {
        return jsonResponse(await stub.getDashboard());
      }

      if (url.pathname === "/api/config/global" && (request.method === "PUT" || request.method === "POST")) {
        const body = await request.json();
        const cfg = body?.config && typeof body.config === "object" ? body.config : body;
        const merge = body?.replace === true ? false : true;
        return jsonResponse(await stub.setGlobalConfig(cfg, merge));
      }

      if (url.pathname.startsWith("/api/config/instance/") && (request.method === "PUT" || request.method === "POST")) {
        const instanceKey = decodeURIComponent(url.pathname.slice("/api/config/instance/".length));
        const body = await request.json();
        const clear = body?.clear === true;
        const cfg = body?.config && typeof body.config === "object" ? body.config : body;
        const res = await stub.setInstanceOverride(instanceKey, cfg, clear);
        return jsonResponse(res, res.ok ? 200 : 404);
      }

      if (url.pathname === "/api/command" && request.method === "POST") {
        const body = await request.json();
        return jsonResponse(await stub.enqueueCommand(body));
      }

      if (url.pathname.startsWith("/api/instance/") && request.method === "DELETE") {
        const instanceKey = decodeURIComponent(url.pathname.slice("/api/instance/".length));
        return jsonResponse(await stub.deleteInstance(instanceKey));
      }

      if (url.pathname === "/api/history" && request.method === "DELETE") {
        return jsonResponse(await stub.clearHistory());
      }

      if (url.pathname === "/api/fingerprint" && request.method === "DELETE") {
        const body = await request.json();
        return jsonResponse(await stub.deleteFingerprint(String(body?.assetKey || "")));
      }

      if (url.pathname.startsWith("/api/fingerprint/") && request.method === "DELETE") {
        const assetKey = decodeURIComponent(url.pathname.slice("/api/fingerprint/".length));
        return jsonResponse(await stub.deleteFingerprint(assetKey));
      }

      if (url.pathname === "/api/fingerprints" && request.method === "DELETE") {
        const mode = url.searchParams.get("mode") || "all";
        return jsonResponse(await stub.clearFingerprints(mode));
      }

      return jsonResponse({ ok: false, error: "Not found" }, 404);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(JSON.stringify({ message: "worker_error", error: msg }));
      return jsonResponse({ ok: false, error: msg }, 500);
    }
  },
};
