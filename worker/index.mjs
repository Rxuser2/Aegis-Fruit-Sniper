import { DurableObject } from "cloudflare:workers";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Aegis-Key",
  "Access-Control-Max-Age": "86400",
};

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
    this.sql = ctx.storage.sql;
    ctx.blockConcurrencyWhile(async () => {
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
          last_seen INTEGER NOT NULL DEFAULT 0
        );

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
    });
  }

  getMetaJson(key, fallback) {
    const row = this.sql.exec("SELECT v, updated_at FROM meta_kv WHERE k = ?", key).toArray()[0];
    if (!row) return { data: fallback, updatedAt: 0 };
    return { data: safeParseJson(row.v, fallback), updatedAt: row.updated_at || 0 };
  }

  setMetaJson(key, data, now) {
    this.sql.exec(
      "INSERT INTO meta_kv (k, v, updated_at) VALUES (?, ?, ?) ON CONFLICT(k) DO UPDATE SET v = excluded.v, updated_at = excluded.updated_at",
      key,
      JSON.stringify(data),
      now
    );
  }

  getFingerprintMeta() {
    const row = this.sql
      .exec("SELECT COUNT(*) AS total, COALESCE(MAX(updated_at), 0) AS max_ts FROM fingerprints")
      .toArray()[0];
    return { total: row?.total || 0, maxTs: row?.max_ts || 0 };
  }

  async syncInstance(payload) {
    const now = Date.now();
    const instanceKey = String(payload.instanceKey || payload.userId || payload.playerName || "").trim();
    if (!instanceKey) {
      throw new Error("Missing instanceKey or userId");
    }

    const playerName = String(payload.playerName || instanceKey);
    const displayName = String(payload.displayName || playerName);
    const userId = String(payload.userId || instanceKey);
    const placeId = Number(payload.placeId || 0);
    const jobId = String(payload.jobId || "").trim();

    const prevInst = this.sql
      .exec("SELECT job_id, override_config_json, override_version FROM instances WHERE instance_key = ?", instanceKey)
      .toArray()[0];

    // If instance hopped away from an old server, mark old server as checked (5 min cross-account cooldown)
    if (prevInst?.job_id && prevInst.job_id !== jobId) {
      this.sql.exec(
        `INSERT INTO server_locks (job_id, place_id, instance_key, player_name, reason, locked_until)
         VALUES (?, ?, ?, ?, 'checked', ?)
         ON CONFLICT(job_id) DO UPDATE SET
           instance_key = excluded.instance_key,
           player_name = excluded.player_name,
           reason = 'checked',
           locked_until = excluded.locked_until`,
        prevInst.job_id,
        placeId,
        instanceKey,
        playerName,
        now + 300_000
      );
    }

    // Keep active server locked as occupied for 6 minutes (refreshed every heartbeat)
    if (jobId) {
      this.sql.exec(
        `INSERT INTO server_locks (job_id, place_id, instance_key, player_name, reason, locked_until)
         VALUES (?, ?, ?, ?, 'occupied', ?)
         ON CONFLICT(job_id) DO UPDATE SET
           place_id = excluded.place_id,
           instance_key = excluded.instance_key,
           player_name = excluded.player_name,
           reason = 'occupied',
           locked_until = excluded.locked_until`,
        jobId,
        placeId,
        instanceKey,
        playerName,
        now + 360_000
      );
    }

    // Prune expired server locks
    this.sql.exec("DELETE FROM server_locks WHERE locked_until < ?", now);

    // Upsert instance telemetry snapshot
    const activeCfg = normalizeMapObject(payload.activeConfig);
    this.sql.exec(
      `INSERT INTO instances (
         instance_key, player_name, display_name, user_id, level, beli, equipped_fruit,
         place_id, job_id, players_count, max_players, status, flight_target,
         map_fruits_json, dealer_stock_json, stored_session, pool_count, learned_count,
         webhook_sent, turbo_mode, active_config_json, override_config_json, override_version, last_seen
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '{}', 0, ?)
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
         last_seen = excluded.last_seen`,
      instanceKey,
      playerName,
      displayName,
      userId,
      Number(payload.level || 0),
      Number(payload.beli || 0),
      String(payload.equippedFruit || "None"),
      placeId,
      jobId,
      Number(payload.playersCount || 0),
      Number(payload.maxPlayers || 12),
      String(payload.status || "IDLE"),
      String(payload.flightTarget || ""),
      JSON.stringify(Array.isArray(payload.mapFruits) ? payload.mapFruits.slice(0, 12) : []),
      JSON.stringify(Array.isArray(payload.dealerStock) ? payload.dealerStock.slice(0, 20) : []),
      Number(payload.storedSession || 0),
      Number(payload.poolCount || 0),
      Number(payload.learnedCount || 0),
      Number(payload.webhookSent || 0),
      payload.turboMode ? 1 : 0,
      JSON.stringify(activeCfg),
      now
    );

    // Merge newly learned fingerprints with collision protection
    const newFps = normalizeMapObject(payload.newFingerprints);
    let uploadedFpCount = 0;
    for (const [assetKey, rawFruitId] of Object.entries(newFps)) {
      if (typeof assetKey !== "string" || typeof rawFruitId !== "string" || !assetKey || !rawFruitId) continue;
      const existing = this.sql.exec("SELECT fruit_id FROM fingerprints WHERE asset_key = ?", assetKey).toArray()[0];
      let targetFruitId = rawFruitId;
      if (existing) {
        if (existing.fruit_id === "__SHARED__" || existing.fruit_id === rawFruitId) continue;
        targetFruitId = "__SHARED__";
      }
      this.sql.exec(
        `INSERT INTO fingerprints (asset_key, fruit_id, learned_by, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(asset_key) DO UPDATE SET fruit_id = excluded.fruit_id, learned_by = excluded.learned_by, updated_at = excluded.updated_at`,
        assetKey,
        targetFruitId,
        playerName,
        now
      );
      uploadedFpCount += 1;
    }

    // Record newly caught/stored fruits
    if (Array.isArray(payload.catches)) {
      for (const c of payload.catches.slice(0, 15)) {
        if (!c || typeof c !== "object" || !c.fruitId) continue;
        const uid = String(c.catchUid || `${instanceKey}:${c.fruitId}:${c.ts || now}`);
        this.sql.exec(
          `INSERT OR IGNORE INTO catch_history (catch_uid, instance_key, player_name, fruit_id, display_name, rarity, icon_url, job_id, source, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          uid,
          instanceKey,
          playerName,
          String(c.fruitId),
          String(c.displayName || c.fruitId),
          String(c.rarity || "Unknown"),
          String(c.iconUrl || ""),
          String(c.jobId || jobId),
          String(c.source || "Map"),
          Number(c.ts || now)
        );
      }
      this.sql.exec(
        "DELETE FROM catch_history WHERE id NOT IN (SELECT id FROM catch_history ORDER BY id DESC LIMIT 150)"
      );
    }

    // Resolve Global + Per-Instance Config updates
    const globalState = this.getMetaJson("global_config", { version: 0, config: {} });
    const instRow = this.sql
      .exec("SELECT override_config_json, override_version FROM instances WHERE instance_key = ?", instanceKey)
      .toArray()[0];
    const overrideVersion = instRow?.override_version || 0;
    const overrideConfig = safeParseJson(instRow?.override_config_json, {});

    const knownGlobalVersion = Number(payload.knownGlobalVersion || 0);
    const knownOverrideVersion = Number(payload.knownOverrideVersion || 0);

    // Pop pending commands for this instance or global wildcard "*"
    this.sql.exec("DELETE FROM commands WHERE created_at < ?", now - 120_000);
    const pendingRows = this.sql
      .exec("SELECT id, target_key, action, payload_json, created_at, consumed_by_json FROM commands WHERE target_key = ? OR target_key = '*' ORDER BY created_at ASC", instanceKey)
      .toArray();
    const outCommands = [];
    for (const cmd of pendingRows) {
      if (cmd.target_key === "*") {
        const consumed = safeParseJson(cmd.consumed_by_json, {});
        if (consumed[instanceKey]) continue;
        consumed[instanceKey] = now;
        this.sql.exec("UPDATE commands SET consumed_by_json = ? WHERE id = ?", JSON.stringify(consumed), cmd.id);
      } else {
        this.sql.exec("DELETE FROM commands WHERE id = ?", cmd.id);
      }
      outCommands.push({
        id: cmd.id,
        action: cmd.action,
        payload: safeParseJson(cmd.payload_json, {}),
        createdAt: cmd.created_at,
      });
    }

    // Collect global blocked JobIds held by OTHER instances
    const lockRows = this.sql
      .exec("SELECT job_id FROM server_locks WHERE locked_until > ? AND instance_key != ? ORDER BY locked_until DESC LIMIT 300", now, instanceKey)
      .toArray();
    const blockedJobIds = lockRows.map((r) => r.job_id);

    // Only transmit global fingerprints if client's state differs from server's max_ts or total
    const fpMeta = this.getFingerprintMeta();
    const knownFpTs = Number(payload.knownFpTs || 0);
    const knownFpTotal = Number(payload.knownFpTotal || -1);
    let globalFingerprints = null;
    if (knownFpTs !== fpMeta.maxTs || knownFpTotal !== fpMeta.total || uploadedFpCount > 0) {
      const fpRows = this.sql.exec("SELECT asset_key, fruit_id FROM fingerprints").toArray();
      globalFingerprints = {};
      for (const r of fpRows) {
        globalFingerprints[r.asset_key] = r.fruit_id;
      }
    }

    return {
      ok: true,
      serverTime: now,
      globalConfigVersion: globalState.data.version || 0,
      globalConfig: (globalState.data.version || 0) !== knownGlobalVersion ? normalizeMapObject(globalState.data.config) : null,
      overrideVersion,
      overrideConfig: overrideVersion !== knownOverrideVersion ? overrideConfig : null,
      commands: outCommands,
      blockedJobIds,
      fpMaxTs: fpMeta.maxTs,
      fpTotal: fpMeta.total,
      globalFingerprints,
    };
  }

  async claimServer(payload) {
    const now = Date.now();
    const instanceKey = String(payload.instanceKey || "").trim();
    const playerName = String(payload.playerName || instanceKey);
    const placeId = Number(payload.placeId || 0);
    const jobId = String(payload.jobId || "").trim();
    const oldJobId = String(payload.oldJobId || "").trim();

    if (!instanceKey || !jobId) {
      return { ok: false, error: "Missing instanceKey or jobId" };
    }

    if (oldJobId && oldJobId !== jobId) {
      this.sql.exec(
        `INSERT INTO server_locks (job_id, place_id, instance_key, player_name, reason, locked_until)
         VALUES (?, ?, ?, ?, 'checked', ?)
         ON CONFLICT(job_id) DO UPDATE SET
           instance_key = excluded.instance_key,
           player_name = excluded.player_name,
           reason = 'checked',
           locked_until = excluded.locked_until`,
        oldJobId,
        placeId,
        instanceKey,
        playerName,
        now + 300_000
      );
    }

    this.sql.exec("DELETE FROM server_locks WHERE locked_until < ?", now);
    const existing = this.sql
      .exec("SELECT instance_key, player_name, reason, locked_until FROM server_locks WHERE job_id = ?", jobId)
      .toArray()[0];

    if (existing && existing.instance_key !== instanceKey && existing.locked_until > now) {
      return {
        ok: false,
        claimedBy: existing.player_name || existing.instance_key,
        reason: existing.reason,
      };
    }

    this.sql.exec(
      `INSERT INTO server_locks (job_id, place_id, instance_key, player_name, reason, locked_until)
       VALUES (?, ?, ?, ?, 'claiming', ?)
       ON CONFLICT(job_id) DO UPDATE SET
         place_id = excluded.place_id,
         instance_key = excluded.instance_key,
         player_name = excluded.player_name,
         reason = 'claiming',
         locked_until = excluded.locked_until`,
      jobId,
      placeId,
      instanceKey,
      playerName,
      now + 120_000
    );

    return { ok: true, jobId };
  }

  async getDashboard() {
    const now = Date.now();
    this.sql.exec("DELETE FROM server_locks WHERE locked_until < ?", now);

    const instRows = this.sql.exec("SELECT * FROM instances ORDER BY last_seen DESC").toArray();
    const instances = instRows.map((r) => ({
      instanceKey: r.instance_key,
      playerName: r.player_name,
      displayName: r.display_name,
      userId: r.user_id,
      level: r.level,
      beli: r.beli,
      equippedFruit: r.equipped_fruit,
      placeId: r.place_id,
      jobId: r.job_id,
      playersCount: r.players_count,
      maxPlayers: r.max_players,
      status: r.status,
      flightTarget: r.flight_target,
      mapFruits: safeParseJson(r.map_fruits_json, []),
      dealerStock: safeParseJson(r.dealer_stock_json, []),
      storedSession: r.stored_session,
      poolCount: r.pool_count,
      learnedCount: r.learned_count,
      webhookSent: r.webhook_sent,
      turboMode: r.turbo_mode === 1,
      activeConfig: safeParseJson(r.active_config_json, {}),
      overrideConfig: safeParseJson(r.override_config_json, {}),
      overrideVersion: r.override_version,
      lastSeen: r.last_seen,
      online: now - r.last_seen < 20_000,
    }));

    const globalState = this.getMetaJson("global_config", { version: 0, config: {} });
    const catchRows = this.sql
      .exec("SELECT id, instance_key, player_name, fruit_id, display_name, rarity, icon_url, job_id, source, created_at FROM catch_history ORDER BY id DESC LIMIT 60")
      .toArray();
    const fpRows = this.sql
      .exec("SELECT asset_key, fruit_id, learned_by, updated_at FROM fingerprints ORDER BY updated_at DESC LIMIT 250")
      .toArray();
    const fpMeta = this.getFingerprintMeta();
    const lockRows = this.sql
      .exec("SELECT job_id, place_id, instance_key, player_name, reason, locked_until FROM server_locks WHERE locked_until > ? ORDER BY locked_until DESC LIMIT 100", now)
      .toArray();

    return {
      ok: true,
      serverTime: now,
      instances,
      globalConfig: globalState.data,
      catchHistory: catchRows,
      fingerprintsTotal: fpMeta.total,
      fingerprints: fpRows,
      serverLocks: lockRows,
    };
  }

  async setGlobalConfig(newConfig, merge = true) {
    const now = Date.now();
    const prev = this.getMetaJson("global_config", { version: 0, config: {} }).data;
    const baseCfg = merge ? normalizeMapObject(prev.config) : {};
    const incoming = normalizeMapObject(newConfig);
    const nextCfg = { ...baseCfg, ...incoming };
    const nextState = {
      version: (prev.version || 0) + 1,
      config: nextCfg,
      updatedAt: now,
    };
    this.setMetaJson("global_config", nextState, now);
    return { ok: true, globalConfig: nextState };
  }

  async setInstanceOverride(instanceKey, overrideConfig, clear = false) {
    const row = this.sql
      .exec("SELECT override_config_json, override_version FROM instances WHERE instance_key = ?", instanceKey)
      .toArray()[0];
    if (!row) {
      return { ok: false, error: "Instance not found" };
    }
    const nextVer = (row.override_version || 0) + 1;
    const prevObj = safeParseJson(row.override_config_json, {});
    const nextObj = clear ? {} : { ...prevObj, ...normalizeMapObject(overrideConfig) };
    // Remove null keys to allow clearing single override field cleanly
    for (const [k, v] of Object.entries(nextObj)) {
      if (v === null) delete nextObj[k];
    }
    this.sql.exec(
      "UPDATE instances SET override_config_json = ?, override_version = ? WHERE instance_key = ?",
      JSON.stringify(nextObj),
      nextVer,
      instanceKey
    );
    return { ok: true, instanceKey, overrideVersion: nextVer, overrideConfig: nextObj };
  }

  async enqueueCommand({ targetKey = "*", action, payload = {} }) {
    if (!action || typeof action !== "string") {
      return { ok: false, error: "Missing action" };
    }
    const now = Date.now();
    const id = crypto.randomUUID();
    this.sql.exec(
      "INSERT INTO commands (id, target_key, action, payload_json, created_at, consumed_by_json) VALUES (?, ?, ?, ?, ?, '{}')",
      id,
      String(targetKey || "*"),
      action,
      JSON.stringify(normalizeMapObject(payload)),
      now
    );
    return { ok: true, id, targetKey, action };
  }

  async deleteInstance(instanceKey) {
    this.sql.exec("DELETE FROM instances WHERE instance_key = ?", instanceKey);
    this.sql.exec("DELETE FROM server_locks WHERE instance_key = ?", instanceKey);
    return { ok: true };
  }

  async clearHistory() {
    this.sql.exec("DELETE FROM catch_history");
    return { ok: true };
  }

  async deleteFingerprint(assetKey) {
    this.sql.exec("DELETE FROM fingerprints WHERE asset_key = ?", assetKey);
    return { ok: true };
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
        return jsonResponse({ ok: true, service: "aegis-fruit-hub", version: "3.2" });
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

      return jsonResponse({ ok: false, error: "Not found" }, 404);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(JSON.stringify({ message: "worker_error", error: msg }));
      return jsonResponse({ ok: false, error: msg }, 500);
    }
  },
};
