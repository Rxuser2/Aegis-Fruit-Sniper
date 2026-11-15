const DEFAULT_API_URL = "https://aegis-fruit-hub.rxuser2-aegis.workers.dev";
const WIKI_BASE = "https://static.wikia.nocookie.net/roblox-blox-piece/images/";
const DEFAULT_ICON = WIKI_BASE + "6/65/Kitsune_Fruit.png";

const RARITIES = ["Mythical", "Legendary", "Rare", "Uncommon", "Common"];
const SEA_NAMES = {
  2753915549: "First Sea",
  4442272183: "Second Sea",
  7449423635: "Third Sea",
};

const FRUIT_CATALOG = [
  { id: "Dragon-Dragon", display: "Dragon", rarity: "Mythical", icon: WIKI_BASE + "2/29/Dragon_Fruit.png" },
  { id: "Kitsune-Kitsune", display: "Kitsune", rarity: "Mythical", icon: WIKI_BASE + "6/65/Kitsune_Fruit.png" },
  { id: "Empyrean (Kitsune)-Empyrean (Kitsune)", display: "Empyrean Kitsune", rarity: "Mythical", icon: WIKI_BASE + "6/65/Kitsune_Fruit.png" },
  { id: "Magnet-Magnet", display: "Magnet", rarity: "Mythical", icon: WIKI_BASE + "2/2f/Magnet_Fruit.png" },
  { id: "Yeti-Yeti", display: "Yeti", rarity: "Mythical", icon: WIKI_BASE + "2/2f/Yeti_Fruit.png" },
  { id: "Fiend (Yeti)-Fiend (Yeti)", display: "Fiend Yeti", rarity: "Mythical", icon: WIKI_BASE + "2/2f/Yeti_Fruit.png" },
  { id: "Tiger-Tiger", display: "Tiger (Leopard)", rarity: "Mythical", icon: WIKI_BASE + "1/14/Tiger_Fruit.png" },
  { id: "Werewolf (Tiger)-Werewolf (Tiger)", display: "Werewolf Tiger", rarity: "Mythical", icon: WIKI_BASE + "1/14/Tiger_Fruit.png" },
  { id: "Leopard-Leopard", display: "Leopard", rarity: "Mythical", icon: WIKI_BASE + "a/a3/Leopard_Fruit.png" },
  { id: "Gas-Gas", display: "Gas", rarity: "Mythical", icon: WIKI_BASE + "e/ed/Gas_Fruit.png" },
  { id: "Spirit-Spirit", display: "Spirit", rarity: "Mythical", icon: WIKI_BASE + "6/66/Spirit_Fruit.png" },
  { id: "Control-Control", display: "Control", rarity: "Mythical", icon: WIKI_BASE + "1/19/Control_Fruit.png" },
  { id: "Venom-Venom", display: "Venom", rarity: "Mythical", icon: WIKI_BASE + "d/d2/Venom_Fruit.png" },
  { id: "Shadow-Shadow", display: "Shadow", rarity: "Mythical", icon: WIKI_BASE + "5/58/Shadow_Fruit.png" },
  { id: "Dough-Dough", display: "Dough", rarity: "Mythical", icon: WIKI_BASE + "0/02/Dough_Fruit.png" },
  { id: "T-Rex-T-Rex", display: "T-Rex", rarity: "Mythical", icon: WIKI_BASE + "d/d9/T-Rex_Fruit.png" },
  { id: "Mammoth-Mammoth", display: "Mammoth", rarity: "Mythical", icon: WIKI_BASE + "9/95/Mammoth_Fruit.png" },
  { id: "Gravity-Gravity", display: "Gravity", rarity: "Mythical", icon: WIKI_BASE + "5/5f/Gravity_Fruit.png" },
  { id: "Blizzard-Blizzard", display: "Blizzard", rarity: "Legendary", icon: WIKI_BASE + "c/c9/Blizzard_Fruit.png" },
  { id: "Pain-Pain", display: "Pain", rarity: "Legendary", icon: WIKI_BASE + "4/40/Pain_Fruit.png" },
  { id: "Lightning-Lightning", display: "Lightning", rarity: "Legendary", icon: WIKI_BASE + "7/78/Lightning_Fruit.png" },
  { id: "Rumble-Rumble", display: "Rumble", rarity: "Legendary", icon: WIKI_BASE + "7/78/Lightning_Fruit.png" },
  { id: "Portal-Portal", display: "Portal", rarity: "Legendary", icon: WIKI_BASE + "8/8a/Portal_Fruit.png" },
  { id: "Phoenix-Phoenix", display: "Phoenix", rarity: "Legendary", icon: WIKI_BASE + "f/fc/Phoenix_Fruit.png" },
  { id: "Sound-Sound", display: "Sound", rarity: "Legendary", icon: WIKI_BASE + "b/ba/Sound_Fruit.png" },
  { id: "Spider-Spider", display: "Spider", rarity: "Legendary", icon: WIKI_BASE + "6/61/Spider_Fruit.png" },
  { id: "Creation-Creation", display: "Creation", rarity: "Legendary", icon: WIKI_BASE + "4/44/Creation_Fruit.png" },
  { id: "Barrier-Barrier", display: "Barrier", rarity: "Legendary", icon: WIKI_BASE + "1/19/Barrier_Fruit.png" },
  { id: "Love-Love", display: "Love", rarity: "Legendary", icon: WIKI_BASE + "b/b3/Love_Fruit.png" },
  { id: "Buddha-Buddha", display: "Buddha", rarity: "Legendary", icon: WIKI_BASE + "d/df/Buddha_Fruit.png" },
  { id: "Quake-Quake", display: "Quake", rarity: "Legendary", icon: WIKI_BASE + "4/42/Quake_Fruit.png" },
  { id: "Magma-Magma", display: "Magma", rarity: "Rare", icon: WIKI_BASE + "2/27/Magma_Fruit.png" },
  { id: "Ghost-Ghost", display: "Ghost", rarity: "Rare", icon: WIKI_BASE + "8/8c/Ghost_Fruit.png" },
  { id: "Rubber-Rubber", display: "Rubber", rarity: "Rare", icon: WIKI_BASE + "5/5c/Rubber_Fruit.png" },
  { id: "Light-Light", display: "Light", rarity: "Rare", icon: WIKI_BASE + "8/83/Light_Fruit.png" },
  { id: "Diamond-Diamond", display: "Diamond", rarity: "Uncommon", icon: WIKI_BASE + "8/88/Diamond_Fruit.png" },
  { id: "Eagle-Eagle", display: "Eagle", rarity: "Uncommon", icon: WIKI_BASE + "5/53/Eagle_Fruit.png" },
  { id: "Falcon-Falcon", display: "Falcon", rarity: "Uncommon", icon: WIKI_BASE + "e/ef/Falcon_Fruit.png" },
  { id: "Dark-Dark", display: "Dark", rarity: "Uncommon", icon: WIKI_BASE + "5/5c/Dark_Fruit.png" },
  { id: "Sand-Sand", display: "Sand", rarity: "Uncommon", icon: WIKI_BASE + "7/72/Sand_Fruit.png" },
  { id: "Ice-Ice", display: "Ice", rarity: "Uncommon", icon: WIKI_BASE + "c/c5/Ice_Fruit.png" },
  { id: "Flame-Flame", display: "Flame", rarity: "Uncommon", icon: WIKI_BASE + "c/c4/Flame_Fruit.png" },
  { id: "Spike-Spike", display: "Spike", rarity: "Common", icon: WIKI_BASE + "c/ce/Spike_Fruit.png" },
  { id: "Smoke-Smoke", display: "Smoke", rarity: "Common", icon: WIKI_BASE + "7/7e/Smoke_Fruit.png" },
  { id: "Bomb-Bomb", display: "Bomb", rarity: "Common", icon: WIKI_BASE + "4/43/Bomb_Fruit.png" },
  { id: "Spring-Spring", display: "Spring", rarity: "Common", icon: WIKI_BASE + "8/8a/Spring_Fruit.png" },
  { id: "Blade-Blade", display: "Blade", rarity: "Common", icon: WIKI_BASE + "0/01/Blade_Fruit.png" },
  { id: "Chop-Chop", display: "Chop", rarity: "Common", icon: WIKI_BASE + "0/0e/Chop_Fruit.png" },
  { id: "Spin-Spin", display: "Spin", rarity: "Common", icon: WIKI_BASE + "8/88/Spin_Fruit.png" },
  { id: "Rocket-Rocket", display: "Rocket", rarity: "Common", icon: WIKI_BASE + "c/cb/Rocket_Fruit.png" },
];

const DEFAULT_CONFIG = {
  AutoSnipeMap: true,
  OnlySnipeFiltered: true,
  SnipeNaturalSpawns: true,
  SnipeUnknownNatural: true,
  SnipeDroppedTools: true,
  AutoStoreFruits: true,
  AutoJoinTeam: "Marines",
  FlightSpeed: 300,
  AutoDealerSniper: false,
  DealerCheckInterval: 20,
  AutoRollGacha: true,
  AutoServerHop: true,
  TurboFastHop: true,
  AutoFixStuck: true,
  AbandonUnreachableFruit: true,
  ServerHopDelay: 2,
  WebSyncInterval: 5,
  FruitESP: true,
  FruitTracers: true,
  ShowMiniHUD: true,
  WebhookEnabled: true,
  WebhookSendBoth: false,
  NotifyOnDetect: true,
  NotifyOnStore: true,
  NotifyOnDealer: true,
  NotifyOnHop: false,
  AllowedRarities: { Mythical: true, Legendary: true, Rare: true, Uncommon: true, Common: true },
  TargetFruits: {
    "Dragon-Dragon": true,
    "Kitsune-Kitsune": true,
    "Empyrean (Kitsune)-Empyrean (Kitsune)": true,
    "Magnet-Magnet": true,
    "Yeti-Yeti": true,
    "Fiend (Yeti)-Fiend (Yeti)": true,
    "Tiger-Tiger": true,
    "Gas-Gas": true,
    "T-Rex-T-Rex": true,
    "Mammoth-Mammoth": true,
    "Dough-Dough": true,
    "Venom-Venom": true,
    "Control-Control": true,
    "Spirit-Spirit": true,
    "Shadow-Shadow": true,
    "Portal-Portal": true,
    "Buddha-Buddha": true,
  },
};

const TOGGLE_GROUPS = {
  sniper: [
    ["AutoSnipeMap", "Auto Snipe Map Fruits"],
    ["OnlySnipeFiltered", "Only Snipe Filtered Fruits"],
    ["SnipeNaturalSpawns", "Snipe Natural Spawns ('Fruit ')"],
    ["SnipeUnknownNatural", "Snipe Unknown Natural (Auto-Learn)"],
    ["SnipeDroppedTools", "Snipe Dropped Fruit Tools"],
    ["AutoStoreFruits", "Auto Store Picked Fruits"],
    ["AutoDealerSniper", "Auto Dealer Sniper"],
    ["AutoRollGacha", "Auto Roll Zioles Gacha"],
  ],
  flight: [
    ["AutoServerHop", "Auto Server Hop (Empty Map)"],
    ["TurboFastHop", "Turbo Fast Scan & Hop (<=1s)"],
    ["AutoFixStuck", "Auto-Fix Stuck (Keluar Air / Reset)"],
    ["AbandonUnreachableFruit", "Relakan Fruit Unreachable & Auto Hop"],
  ],
  visual: [
    ["FruitESP", "3D Fruit ESP"],
    ["FruitTracers", "3D Fruit Tracers"],
    ["ShowMiniHUD", "Floating Mini HUD"],
    ["WebhookEnabled", "Discord Webhooks Enabled"],
    ["WebhookSendBoth", "Send Both Primary + Backup"],
    ["NotifyOnDetect", "Notify Fruit Spawn"],
    ["NotifyOnStore", "Notify Fruit Stored"],
    ["NotifyOnDealer", "Notify Dealer Match"],
    ["NotifyOnHop", "Notify Server Hop"],
  ],
};

const PRESETS = {
  turbo_mythical: {
    AutoSnipeMap: true,
    OnlySnipeFiltered: true,
    SnipeNaturalSpawns: true,
    SnipeUnknownNatural: false,
    SnipeDroppedTools: true,
    AutoStoreFruits: true,
    AutoServerHop: true,
    TurboFastHop: true,
    ServerHopDelay: 1,
    AllowedRarities: { Mythical: true, Legendary: true, Rare: false, Uncommon: false, Common: false },
  },
  auto_learn: {
    AutoSnipeMap: true,
    OnlySnipeFiltered: false,
    SnipeNaturalSpawns: true,
    SnipeUnknownNatural: true,
    SnipeDroppedTools: true,
    AutoStoreFruits: true,
    AutoServerHop: true,
    TurboFastHop: true,
    ServerHopDelay: 2,
    AllowedRarities: { Mythical: true, Legendary: true, Rare: true, Uncommon: true, Common: true },
  },
  gacha_idle: {
    AutoSnipeMap: false,
    AutoServerHop: false,
    AutoRollGacha: true,
    AutoStoreFruits: true,
  },
  pause_all: {
    AutoSnipeMap: false,
    AutoServerHop: false,
  },
};

const state = {
  apiUrl: localStorage.getItem("aegis_worker_url") || DEFAULT_API_URL,
  accessKey: localStorage.getItem("aegis_access_key") || "",
  dashboard: null,
  pollTimer: null,
  configTarget: "__global__",
  draftConfig: structuredClone(DEFAULT_CONFIG),
  configInitialized: false,
  altRouteTarget: null,
  invRarityFilter: "ALL",
  invOnlyOnline: false,
  serverOffsetMs: 0,
  pollErrorCount: 0,
  pollingActive: false,
  refreshInFlight: false,
};

const $ = (id) => document.getElementById(id);

function escapeHtml(val) {
  return String(val ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function toast(msg, isErr = false) {
  const box = document.createElement("div");
  box.className = "toast" + (isErr ? " err" : "");
  const icon = document.createElement("span");
  icon.className = "toast-icon";
  icon.textContent = isErr ? "⚠️" : "✅";
  const text = document.createElement("span");
  text.textContent = msg;
  box.append(icon, text);
  $("toast-container").appendChild(box);
  setTimeout(() => {
    box.classList.add("leaving");
    setTimeout(() => box.remove(), 260);
  }, 3200);
}

// Smooth number count-up for KPI values (skips animation when reduced motion is requested)
const kpiLast = {};
function setKpiNumber(id, value, formatter = formatNumber) {
  const el = $(id);
  if (!el) return;
  const target = Number(value) || 0;
  const from = kpiLast[id] ?? target;
  kpiLast[id] = target;
  if (from === target || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    el.textContent = formatter(target);
    return;
  }
  const start = performance.now();
  const dur = 600;
  const step = (now) => {
    const t = Math.min(1, (now - start) / dur);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = formatter(Math.round(from + (target - from) * eased));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function formatNumber(n) {
  return Number(n || 0).toLocaleString("en-US");
}

function formatAge(msDiff) {
  const s = Math.max(0, Math.floor(msDiff / 1000));
  if (s < 60) return `${s}d lalu`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m lalu`;
  const h = Math.floor(m / 60);
  return `${h}j lalu`;
}

function formatUptime(msDiff) {
  const totalSec = Math.max(0, Math.floor(msDiff / 1000));
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const mins = Math.floor((totalSec % 3600) / 60);
  const secs = totalSec % 60;
  const pad = (n) => String(n).padStart(2, "0");
  if (days > 0) return `${days}h ${pad(hours)}j ${pad(mins)}m`;
  if (hours > 0) return `${hours}j ${pad(mins)}m ${pad(secs)}d`;
  if (mins > 0) return `${mins}m ${pad(secs)}d`;
  return `${secs}d`;
}

function getInstanceUptimeMs(inst, refServerMs) {
  const start = Number(inst.startedAt || inst.lastSeen || refServerMs);
  const end = inst.online ? refServerMs : Number(inst.lastSeen || refServerMs);
  return Math.max(0, end - start);
}

async function apiFetch(path, options = {}) {
  const url = state.apiUrl.replace(/\/+$/, "") + path;
  const res = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "X-Aegis-Key": state.accessKey,
      ...(options.headers || {}),
    },
  });
  if (res.status === 401) {
    throw new Error("Access Key salah (HTTP 401)");
  }
  const data = await res.json();
  if (!res.ok || data.ok === false) {
    throw new Error(data.error || `HTTP ${res.status}`);
  }
  return data;
}

function parseUrlFragmentCreds() {
  if (!window.location.hash) return;
  const params = new URLSearchParams(window.location.hash.slice(1));
  const key = params.get("key");
  const api = params.get("api");
  if (key) {
    state.accessKey = key.trim();
    localStorage.setItem("aegis_access_key", state.accessKey);
  }
  if (api) {
    state.apiUrl = api.trim().replace(/\/+$/, "");
    localStorage.setItem("aegis_worker_url", state.apiUrl);
  }
  if (key || api) {
    history.replaceState(null, "", window.location.pathname + window.location.search);
  }
}

async function tryUnlock() {
  $("login-error").classList.add("hidden");
  $("btn-login").disabled = true;
  $("btn-login").textContent = "Memverifikasi...";
  try {
    await apiFetch("/api/verify");
    localStorage.setItem("aegis_worker_url", state.apiUrl);
    localStorage.setItem("aegis_access_key", state.accessKey);
    $("login-screen").classList.add("hidden");
    $("app-shell").classList.remove("hidden");
    await refreshDashboard(true);
    startPolling();
  } catch (err) {
    $("login-error").textContent = err.message;
    $("login-error").classList.remove("hidden");
    stopPolling();
  } finally {
    $("btn-login").disabled = false;
    $("btn-login").textContent = "Masuk ke Dashboard";
  }
}

function lockDashboard() {
  stopPolling();
  state.accessKey = "";
  localStorage.removeItem("aegis_access_key");
  $("input-access-key").value = "";
  $("app-shell").classList.add("hidden");
  $("login-screen").classList.remove("hidden");
}

function scheduleNextPoll() {
  if (!state.pollingActive) return;
  if (state.pollTimer) {
    clearTimeout(state.pollTimer);
    state.pollTimer = null;
  }
  const delayMs =
    state.pollErrorCount > 0
      ? Math.min(15000, 4000 * Math.pow(2, Math.min(state.pollErrorCount, 2)))
      : 4000;
  state.pollTimer = setTimeout(async () => {
    if (!state.pollingActive) return;
    if (document.visibilityState === "visible") {
      await refreshDashboard(false);
    }
    scheduleNextPoll();
  }, delayMs);
}

function startPolling() {
  stopPolling();
  state.pollingActive = true;
  state.pollErrorCount = 0;
  scheduleNextPoll();
}

function stopPolling() {
  state.pollingActive = false;
  if (state.pollTimer) {
    clearTimeout(state.pollTimer);
    state.pollTimer = null;
  }
}

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && state.pollingActive && !state.refreshInFlight) {
    refreshDashboard(false).finally(scheduleNextPoll);
  }
});

async function refreshDashboard(forceConfigSync = false) {
  if (state.refreshInFlight && !forceConfigSync) return;
  state.refreshInFlight = true;
  try {
    const data = await apiFetch("/api/dashboard");
    state.dashboard = data;
    state.pollErrorCount = 0;
    $("conn-dot").classList.remove("err");
    const syncTime = new Date(data.serverTime).toLocaleTimeString("id-ID");
    $("conn-subtitle").textContent = data.cacheStatus?.quotaDegraded
      ? `Terhubung (Mode RAM Darurat s.d. reset 00:00 UTC) • Sync ${syncTime}`
      : `Terhubung • Sync ${syncTime}`;
    renderAll(forceConfigSync);
  } catch (err) {
    state.pollErrorCount += 1;
    $("conn-dot").classList.add("err");
    $("conn-subtitle").textContent = "Terputus: " + err.message;
    if (err.message.includes("401")) {
      lockDashboard();
    }
  } finally {
    state.refreshInFlight = false;
  }
}

function renderAll(forceConfigSync) {
  const d = state.dashboard;
  if (!d) return;

  const instances = d.instances || [];
  const onlineList = instances.filter((x) => x.online);
  const flyingCount = onlineList.filter((x) => x.flightTarget).length;
  const totalStored = instances.reduce((acc, x) => acc + (x.storedSession || 0), 0);
  const totalInvCount = instances.reduce(
    (acc, x) => acc + Number(x.inventory?.totalStoredCount || 0) + Number((x.inventory?.held || []).length || 0),
    0
  );
  state.serverOffsetMs = Number(d.serverTime || Date.now()) - Date.now();

  $("badge-online").textContent = String(onlineList.length);
  if ($("badge-inv-total")) $("badge-inv-total").textContent = formatNumber(totalInvCount);
  $("kpi-online").textContent = `${onlineList.length} / ${instances.length}`;
  $("kpi-in-flight").textContent = `${flyingCount} sedang terbang`;
  setKpiNumber("kpi-stored", totalStored);
  $("kpi-catches").textContent = `${(d.catchHistory || []).length} log terbaru di cloud`;
  setKpiNumber("kpi-fp", d.fingerprintsTotal || 0);
  setKpiNumber("kpi-locks", (d.serverLocks || []).length);
  const onlinePct = instances.length ? Math.round((onlineList.length / instances.length) * 100) : 0;
  const bar = $("kpi-online-bar");
  if (bar) bar.style.width = `${onlinePct}%`;
  const updated = $("last-updated");
  if (updated) updated.textContent = `Update terakhir ${new Date().toLocaleTimeString("id-ID")}`;

  renderInstances(instances, d.serverTime);
  renderInventoryMatrix(instances, d.serverTime);
  syncTargetSelector(instances);
  if (forceConfigSync || !state.configInitialized) {
    loadDraftConfigForTarget(state.configTarget);
    state.configInitialized = true;
  }
  renderIntel(d);
}

function renderInstances(instances, serverTime) {
  const grid = $("instances-grid");
  if (!instances.length) {
    grid.innerHTML = `
      <div class="empty-state glass">
        <div class="empty-orb">🍏</div>
        <h3>Belum Ada Instance Terhubung</h3>
        <p class="muted small">Jalankan <code>GreatestFruitSniper.luau</code> di executor Roblox Anda dengan Access Key yang sama, maka instance akan muncul otomatis di sini dalam beberapa detik.</p>
      </div>`;
    return;
  }

  grid.innerHTML = instances
    .map((inst) => {
      const seaLabel = SEA_NAMES[inst.placeId] || `Place ${inst.placeId}`;
      const age = formatAge(serverTime - inst.lastSeen);
      const shortJob = inst.jobId ? inst.jobId.slice(0, 14) + "..." : "-";
      const fruits = Array.isArray(inst.mapFruits) ? inst.mapFruits : [];

      const fruitRows = fruits.length
        ? fruits
            .map((f) => {
              const skipped = !f.matchesFilter && inst.activeConfig?.OnlySnipeFiltered;
              return `
              <div class="fruit-row r-${escapeHtml(f.rarity || "Unknown")} ${skipped ? "skipped" : ""}">
                <div class="fruit-left">
                  <img class="fruit-icon" src="${escapeHtml(f.icon || DEFAULT_ICON)}" alt="" onerror="this.src='${DEFAULT_ICON}'" />
                  <div>
                    <div><strong>${escapeHtml(f.display || f.name)}</strong> ${f.isNatural ? '<span class="tiny cyan">[NATURAL]</span>' : '<span class="tiny muted">[DROP]</span>'}</div>
                    <div class="tiny muted">${escapeHtml(f.distance)} studs • ${skipped ? "Dilewati Filter" : "Target"}</div>
                  </div>
                </div>
                <span class="rarity-tag rarity-${escapeHtml(f.rarity || "Unknown")}">${escapeHtml(f.rarity || "Unknown")}</span>
              </div>`;
            })
            .join("")
        : `<div class="tiny muted" style="padding: 4px 2px;">Tidak ada fruit di Workspace server ini.</div>`;

      const hasOverride = Object.keys(inst.overrideConfig || {}).length > 0;
      const uptimeMs = getInstanceUptimeMs(inst, serverTime);
      const uptimeText = formatUptime(uptimeMs);
      const startedAt = Number(inst.startedAt || 0);
      const inv = inst.inventory || {};
      const storedList = Array.isArray(inv.stored) ? inv.stored : [];
      const heldList = Array.isArray(inv.held) ? inv.held : [];
      const storedTotal = Number(inv.totalStoredCount ?? storedList.reduce((acc, f) => acc + Number(f.count || 1), 0));
      const storedTop = storedList.slice(0, 6).map((f) => {
        const rarity = String(f.rarity || "Unknown");
        const cnt = Number(f.count || 1);
        return `<span class="mini-fruit-pill r-${escapeHtml(rarity)}" title="${escapeHtml(f.display || f.id)} (${escapeHtml(rarity)})"><img src="${escapeHtml(f.icon || DEFAULT_ICON)}" alt="" loading="lazy" onerror="this.src='${DEFAULT_ICON}'" /><span>${escapeHtml(f.display || f.id)}</span>${cnt > 1 ? `<strong>×${cnt}</strong>` : ""}</span>`;
      }).join("");
      const heldTop = heldList.slice(0, 4).map((h) => {
        const rarity = String(h.rarity || "Unknown");
        return `<span class="mini-fruit-pill held r-${escapeHtml(rarity)}" title="${escapeHtml(h.display || h.id)} (Backpack)"><img src="${escapeHtml(h.icon || DEFAULT_ICON)}" alt="" loading="lazy" onerror="this.src='${DEFAULT_ICON}'" /><span>🖐 ${escapeHtml(h.display || h.id)}</span><strong>BP</strong></span>`;
      }).join("");
      const invPreviewHtml = (storedTop || heldTop)
        ? `<div class="mini-fruit-grid">${heldTop}${storedTop}${storedList.length > 6 ? `<button type="button" class="mini-fruit-more" data-act="open-inv" data-key="${escapeHtml(inst.instanceKey)}">+${storedList.length - 6}</button>` : ""}</div>`
        : `<div class="tiny muted">Inventory belum tersinkron.</div>`;

      const initial = escapeHtml((inst.playerName || "?").trim().charAt(0).toUpperCase() || "?");
      const flying = inst.online && inst.flightTarget;
      return `
      <article class="inst-card glass ${inst.online ? "online" : "offline"} ${flying ? "flying" : ""}">
        <div class="inst-top">
          <div class="inst-id">
            <div class="avatar">${initial}<span class="avatar-dot"></span></div>
            <div>
              <div class="inst-name">${escapeHtml(inst.playerName)} ${hasOverride ? '<span class="tag-override">Override</span>' : ""}</div>
              <div class="tiny muted">Lv.${formatNumber(inst.level)} • $${formatNumber(inst.beli)} Beli • Fruit: ${escapeHtml(inst.equippedFruit || "None")}</div>
            </div>
          </div>
          <div class="inst-badges">
            <span class="status-pill ${inst.online ? "online" : "offline"}">${inst.online ? "ONLINE" : "OFFLINE"} • ${age}</span>
            <span class="uptime-chip ${inst.online ? "live" : ""}" data-uptime-started="${Number(startedAt || inst.lastSeen || serverTime)}" data-uptime-last="${Number(inst.lastSeen || serverTime)}" data-uptime-online="${inst.online ? "1" : "0"}" title="Lama berjalan akun">⏱️ ${escapeHtml(uptimeText)}</span>
          </div>
        </div>

        <div class="inst-live-box">
          <div class="live-status">${flying ? "🚀 " : ""}${escapeHtml(inst.status || "IDLE")}</div>
          <div class="tiny muted" style="margin-top: 4px;">
            ${escapeHtml(seaLabel)} • Players: ${inst.playersCount}/${inst.maxPlayers} • JobId: <code class="mono">${escapeHtml(shortJob)}</code>
          </div>
        </div>

        <div class="inst-stats">
          <div class="stat-mini"><span class="muted">Stored</span><strong>${inst.storedSession}</strong></div>
          <div class="stat-mini"><span class="muted">Pool</span><strong>${inst.poolCount}</strong></div>
          <div class="stat-mini"><span class="muted">Inv</span><strong>${storedTotal}</strong></div>
          <div class="stat-mini"><span class="muted">Turbo</span><strong>${inst.turboMode ? "ON" : "OFF"}</strong></div>
        </div>

        <div class="card-inv-box">
          <div class="card-inv-head">
            <span class="tiny muted">Inventory (${storedTotal} stored${heldList.length ? `, ${heldList.length} held` : ""})</span>
            <button type="button" class="link-btn tiny" data-act="open-inv" data-key="${escapeHtml(inst.instanceKey)}">Lihat semua →</button>
          </div>
          ${invPreviewHtml}
        </div>

        <div class="fruit-strip">${fruitRows}</div>

        <div class="inst-actions">
          <button class="btn btn-xs btn-cyan" data-act="cmd" data-key="${escapeHtml(inst.instanceKey)}" data-cmd="force_hop">🌐 Hop</button>
          <button class="btn btn-xs btn-ghost" data-act="cmd" data-key="${escapeHtml(inst.instanceKey)}" data-cmd="fix_stuck">🚑 Fix</button>
          <button class="btn btn-xs btn-ghost" data-act="cmd" data-key="${escapeHtml(inst.instanceKey)}" data-cmd="rescan">📡 Scan</button>
          <button class="btn btn-xs btn-ghost" data-act="cmd" data-key="${escapeHtml(inst.instanceKey)}" data-cmd="roll_gacha">🎰 Gacha</button>
          <button class="btn btn-xs btn-primary" data-act="backup" data-key="${escapeHtml(inst.instanceKey)}">🚀 Kirim Alt ke Sini</button>
          <button class="btn btn-xs btn-ghost" data-act="copy-join" data-key="${escapeHtml(inst.instanceKey)}">📋 Copy Join</button>
          <button class="btn btn-xs btn-ghost" data-act="edit-cfg" data-key="${escapeHtml(inst.instanceKey)}">⚙️ Config</button>
          <button class="btn btn-xs btn-danger-ghost" data-act="cmd" data-key="${escapeHtml(inst.instanceKey)}" data-cmd="remote_stop">🛑 Stop</button>
          ${!inst.online ? `<button class="btn btn-xs btn-danger-ghost" data-act="delete" data-key="${escapeHtml(inst.instanceKey)}">🗑️</button>` : ""}
        </div>
      </article>`;
    })
    .join("");
}

function renderInventoryMatrix(instances, serverTime) {
  const grid = $("inventory-grid");
  if (!grid) return;

  const query = ($("inv-search")?.value || "").trim().toLowerCase();
  const rarityFilter = state.invRarityFilter || "ALL";
  const onlyOnline = state.invOnlyOnline === true;
  const visible = onlyOnline ? instances.filter((x) => x.online) : instances;

  let grandTotalCount = 0;
  let grandTotalValue = 0;
  for (const inst of visible) {
    grandTotalCount += Number(inst.inventory?.totalStoredCount || 0) + Number((inst.inventory?.held || []).length || 0);
    grandTotalValue += Number(inst.inventory?.totalValue || 0);
  }
  if ($("inv-summary-line")) {
    $("inv-summary-line").textContent = `${formatNumber(grandTotalCount)} fruit tersimpan • Estimasi $${formatNumber(grandTotalValue)} Beli • ${visible.length} akun`;
  }

  if (!visible.length) {
    grid.innerHTML = `
      <div class="empty-state glass">
        <div class="empty-orb">🎒</div>
        <h3>Tidak Ada Akun Ditampilkan</h3>
        <p class="muted small">Jalankan bot atau matikan filter "Hanya Online" untuk melihat semua inventory akun.</p>
      </div>`;
    return;
  }

  const matchesItem = (item) => {
    if (rarityFilter !== "ALL" && (item.rarity || "Unknown") !== rarityFilter) return false;
    if (!query) return true;
    return (
      String(item.display || "").toLowerCase().includes(query) ||
      String(item.id || "").toLowerCase().includes(query) ||
      String(item.rarity || "").toLowerCase().includes(query)
    );
  };

  grid.innerHTML = visible
    .map((inst) => {
      const inv = inst.inventory || {};
      const stored = (Array.isArray(inv.stored) ? inv.stored : []).filter(matchesItem);
      const held = (Array.isArray(inv.held) ? inv.held : []).filter(matchesItem);
      const initial = escapeHtml((inst.playerName || "?").trim().charAt(0).toUpperCase() || "?");
      const uptimeMs = getInstanceUptimeMs(inst, serverTime);

      const heldHtml = held.length
        ? `<div class="inv-held-strip">
             <div class="tiny amber" style="font-weight:700; margin-bottom:6px;">🖐️ Di Backpack / Tangan (${held.length})</div>
             <div class="inv-fruit-grid">
               ${held
                 .map(
                   (f) => `
                   <div class="inv-fruit-tile r-${escapeHtml(f.rarity || "Unknown")} held">
                     <img src="${escapeHtml(f.icon || DEFAULT_ICON)}" alt="" loading="lazy" onerror="this.src='${DEFAULT_ICON}'" />
                     <div class="inv-tile-info">
                       <div class="inv-tile-name">${escapeHtml(f.display || f.id)}</div>
                       <div class="tiny muted">${escapeHtml(f.rarity || "Unknown")}</div>
                     </div>
                     <span class="inv-count-badge held">BP</span>
                   </div>`
                 )
                 .join("")}
             </div>
           </div>`
        : "";

      const storedHtml = stored.length
        ? `<div class="inv-fruit-grid">
             ${stored
               .map(
                 (f) => `
                 <div class="inv-fruit-tile r-${escapeHtml(f.rarity || "Unknown")}">
                   <img src="${escapeHtml(f.icon || DEFAULT_ICON)}" alt="" loading="lazy" onerror="this.src='${DEFAULT_ICON}'" />
                   <div class="inv-tile-info">
                     <div class="inv-tile-name">${escapeHtml(f.display || f.id)}</div>
                     <div class="tiny muted">${escapeHtml(f.rarity || "Unknown")}</div>
                   </div>
                   <span class="inv-count-badge">x${Number(f.count || 1)}</span>
                 </div>`
               )
               .join("")}
           </div>`
        : `<div class="muted small" style="padding: 10px 4px;">${query || rarityFilter !== "ALL" ? "Tidak ada fruit cocok dengan filter." : "Inventory tersimpan kosong / belum tersinkron."}</div>`;

      return `
      <article class="inv-account-card glass ${inst.online ? "online" : "offline"}">
        <div class="inst-top">
          <div class="inst-id">
            <div class="avatar">${initial}<span class="avatar-dot"></span></div>
            <div>
              <div class="inst-name">${escapeHtml(inst.playerName)}</div>
              <div class="tiny muted">Lv.${formatNumber(inst.level)} • $${formatNumber(inst.beli)} Beli • Pakai: ${escapeHtml(inst.equippedFruit || "None")}</div>
            </div>
          </div>
          <div class="inst-badges">
            <span class="status-pill ${inst.online ? "online" : "offline"}">${inst.online ? "ONLINE" : "OFFLINE"}</span>
            <span class="uptime-chip" data-uptime-started="${Number(inst.startedAt || inst.lastSeen || serverTime)}" data-uptime-last="${Number(inst.lastSeen || serverTime)}" data-uptime-online="${inst.online ? "1" : "0"}">⏱️ ${formatUptime(uptimeMs)}</span>
          </div>
        </div>

        <div class="inv-account-meta">
          <span>📦 Stored: <strong>${formatNumber(inv.totalStoredCount || 0)}</strong> (${formatNumber(inv.totalUnique || 0)} jenis)</span>
          <span>💎 Value: <strong class="emerald">$${formatNumber(inv.totalValue || 0)}</strong></span>
        </div>

        ${heldHtml}
        ${storedHtml}
      </article>`;
    })
    .join("");
}

function syncTargetSelector(instances) {
  const sel = $("cfg-target-select");
  const prev = sel.value;
  const opts = [`<option value="__global__">🌐 Global Config (Semua Instance)</option>`];
  for (const inst of instances) {
    const hasOv = Object.keys(inst.overrideConfig || {}).length > 0 ? " ★ Override" : "";
    opts.push(
      `<option value="${escapeHtml(inst.instanceKey)}">👤 ${escapeHtml(inst.playerName)}${hasOv}</option>`
    );
  }
  sel.innerHTML = opts.join("");
  if ([...sel.options].some((o) => o.value === prev)) {
    sel.value = prev;
  } else {
    sel.value = "__global__";
    state.configTarget = "__global__";
  }
}

function normalizeDict(obj, fallback) {
  if (!obj || typeof obj !== "object" || Array.isArray(obj)) return { ...fallback };
  return { ...obj };
}

function loadDraftConfigForTarget(targetKey) {
  const d = state.dashboard;
  const globalCfg = d?.globalConfig?.config || {};
  const base = {
    ...structuredClone(DEFAULT_CONFIG),
    ...globalCfg,
    AllowedRarities: normalizeDict(globalCfg.AllowedRarities, DEFAULT_CONFIG.AllowedRarities),
    TargetFruits: normalizeDict(globalCfg.TargetFruits, DEFAULT_CONFIG.TargetFruits),
  };

  if (targetKey !== "__global__") {
    const inst = (d?.instances || []).find((x) => x.instanceKey === targetKey);
    const active = inst?.activeConfig || {};
    const ov = inst?.overrideConfig || {};
    Object.assign(base, active, ov);
    base.AllowedRarities = normalizeDict(ov.AllowedRarities || active.AllowedRarities, base.AllowedRarities);
    base.TargetFruits = normalizeDict(ov.TargetFruits || active.TargetFruits, base.TargetFruits);
    $("cfg-target-desc").textContent = `Mengedit Override khusus untuk ${inst?.playerName || targetKey}. Field yang disimpan akan menimpa Global Config untuk akun ini.`;
    $("btn-clear-override").classList.remove("hidden");
  } else {
    $("cfg-target-desc").textContent = `Mengubah Global Config (berlaku ke semua akun, Versi Global v${d?.globalConfig?.version || 0}).`;
    $("btn-clear-override").classList.add("hidden");
  }

  state.draftConfig = base;
  renderConfigEditor();
}

function renderConfigEditor() {
  const cfg = state.draftConfig;

  const renderToggleGroup = (containerId, pairs) => {
    $(containerId).innerHTML = pairs
      .map(
        ([key, label]) => `
        <label class="toggle-item">
          <span>${escapeHtml(label)}</span>
          <input type="checkbox" class="switch-input" data-cfg-bool="${key}" ${cfg[key] ? "checked" : ""} />
          <span class="switch" aria-hidden="true"></span>
        </label>`
      )
      .join("");
  };

  renderToggleGroup("cfg-toggles-sniper", TOGGLE_GROUPS.sniper);
  renderToggleGroup("cfg-toggles-flight", TOGGLE_GROUPS.flight);
  renderToggleGroup("cfg-toggles-visual", TOGGLE_GROUPS.visual);

  $("cfg-team").value = cfg.AutoJoinTeam || "Marines";
  $("cfg-WebSyncInterval").value = cfg.WebSyncInterval ?? 5;
  $("cfg-FlightSpeed").value = cfg.FlightSpeed ?? 300;
  $("cfg-ServerHopDelay").value = cfg.ServerHopDelay ?? 2;
  $("cfg-DealerCheckInterval").value = cfg.DealerCheckInterval ?? 20;

  renderRarityPills();
  renderFruitWatchlist();
}

function renderRarityPills() {
  const allowed = state.draftConfig.AllowedRarities || {};
  $("cfg-rarities").innerHTML = RARITIES.map(
    (r) =>
      `<button type="button" class="pill-toggle ${allowed[r] ? "active" : ""}" data-rarity-pill="${r}">${r}</button>`
  ).join("");
}

function renderFruitWatchlist() {
  const query = ($("fruit-search").value || "").trim().toLowerCase();
  const target = state.draftConfig.TargetFruits || {};
  const list = FRUIT_CATALOG.filter(
    (f) => !query || f.display.toLowerCase().includes(query) || f.id.toLowerCase().includes(query) || f.rarity.toLowerCase().includes(query)
  );
  $("cfg-fruits-grid").innerHTML = list
    .map(
      (f) => `
      <div class="fruit-chip ${target[f.id] ? "active" : ""}" data-fruit-id="${escapeHtml(f.id)}">
        <img src="${escapeHtml(f.icon)}" alt="" loading="lazy" onerror="this.src='${DEFAULT_ICON}'" />
        <div>
          <div style="font-weight: 600;">${escapeHtml(f.display)}</div>
          <div class="tiny muted">${escapeHtml(f.rarity)}</div>
        </div>
      </div>`
    )
    .join("");
}

function collectDraftFromInputs() {
  const cfg = state.draftConfig;
  document.querySelectorAll("[data-cfg-bool]").forEach((el) => {
    cfg[el.dataset.cfgBool] = el.checked;
  });
  cfg.AutoJoinTeam = $("cfg-team").value;
  cfg.WebSyncInterval = Math.max(2, Math.min(30, Number($("cfg-WebSyncInterval").value || 5)));
  cfg.FlightSpeed = Math.max(100, Math.min(350, Number($("cfg-FlightSpeed").value || 300)));
  cfg.ServerHopDelay = Math.max(0, Math.min(120, Number($("cfg-ServerHopDelay").value || 2)));
  cfg.DealerCheckInterval = Math.max(10, Math.min(120, Number($("cfg-DealerCheckInterval").value || 20)));
  return cfg;
}

async function saveConfigToCloud() {
  const cfg = collectDraftFromInputs();
  const btn = $("btn-save-config");
  btn.disabled = true;
  btn.textContent = "Menyimpan...";
  try {
    if (state.configTarget === "__global__") {
      await apiFetch("/api/config/global", {
        method: "PUT",
        body: JSON.stringify({ config: cfg, replace: true }),
      });
      toast("Global Config disimpan & dikirim ke semua instance!");
    } else {
      await apiFetch(`/api/config/instance/${encodeURIComponent(state.configTarget)}`, {
        method: "PUT",
        body: JSON.stringify({ config: cfg }),
      });
      toast("Override Config akun disimpan!");
    }
    await refreshDashboard(true);
  } catch (err) {
    toast(err.message, true);
  } finally {
    btn.disabled = false;
    btn.textContent = "💾 Simpan & Terapkan ke Bot";
  }
}

function renderIntel(d) {
  const catches = d.catchHistory || [];
  $("history-list").innerHTML = catches.length
    ? catches
        .map(
          (c) => `
          <div class="list-row">
            <div class="fruit-left">
              <img class="fruit-icon" src="${escapeHtml(c.icon_url || DEFAULT_ICON)}" alt="" onerror="this.src='${DEFAULT_ICON}'" />
              <div>
                <div><strong>${escapeHtml(c.display_name)}</strong> <span class="rarity-tag rarity-${escapeHtml(c.rarity)}">${escapeHtml(c.rarity)}</span></div>
                <div class="tiny muted">${escapeHtml(c.player_name)} • ${escapeHtml(c.source)} • ${new Date(c.created_at).toLocaleTimeString("id-ID")}</div>
              </div>
            </div>
            <code class="tiny muted mono">${escapeHtml((c.job_id || "").slice(0, 10))}</code>
          </div>`
        )
        .join("")
    : `<div class="muted small">Belum ada riwayat fruit tersimpan di cloud.</div>`;

  // Pick newest non-empty dealerStock from instances
  const withDealer = (d.instances || []).find((i) => Array.isArray(i.dealerStock) && i.dealerStock.length > 0);
  const dealer = withDealer?.dealerStock || [];
  $("dealer-source").textContent = withDealer ? `Via ${withDealer.playerName}` : "Belum ada data";
  $("dealer-list").innerHTML = dealer.length
    ? dealer
        .map(
          (item) => `
          <div class="list-row">
            <div class="fruit-left">
              <img class="fruit-icon" src="${escapeHtml(item.icon || DEFAULT_ICON)}" alt="" onerror="this.src='${DEFAULT_ICON}'" />
              <div>
                <strong>${escapeHtml(item.name)}</strong>
                <div class="tiny muted">$${formatNumber(item.price)} Beli</div>
              </div>
            </div>
            <span class="rarity-tag rarity-${escapeHtml(item.rarity)}">${escapeHtml(item.rarity)}</span>
          </div>`
        )
        .join("")
    : `<div class="muted small">Stok Dealer belum dilaporkan oleh instance aktif.</div>`;

  const fpQuery = ($("fp-search").value || "").trim().toLowerCase();
  const fps = (d.fingerprints || []).filter(
    (f) => !fpQuery || f.fruit_id.toLowerCase().includes(fpQuery) || f.asset_key.toLowerCase().includes(fpQuery)
  );
  $("db-count").textContent = String(d.fingerprintsTotal || 0);
  $("fp-list").innerHTML = fps.length
    ? fps
        .slice(0, 80)
        .map(
          (f) => `
          <div class="list-row">
            <div style="min-width:0; overflow:hidden;">
              <div><strong>${escapeHtml(f.fruit_id)}</strong> <span class="tiny muted">oleh ${escapeHtml(f.learned_by || "-")}</span></div>
              <div class="tiny mono muted" style="text-overflow:ellipsis; overflow:hidden; white-space:nowrap;">${escapeHtml(f.asset_key)}</div>
            </div>
            <button class="btn btn-xs btn-danger-ghost" data-del-fp="${escapeHtml(f.asset_key)}">🗑️</button>
          </div>`
        )
        .join("")
    : `<div class="muted small">Belum ada fingerprint 3D tersimpan.</div>`;

  const locks = d.serverLocks || [];
  $("locks-list").innerHTML = locks.length
    ? locks
        .map((lk) => {
          const remSec = Math.max(0, Math.floor((lk.locked_until - d.serverTime) / 1000));
          return `
          <div class="list-row">
            <div>
              <div><strong>${escapeHtml(lk.player_name || lk.instance_key)}</strong> <span class="tiny cyan">[${escapeHtml(lk.reason)}]</span></div>
              <div class="tiny mono muted">${escapeHtml(lk.job_id)}</div>
            </div>
            <span class="tiny muted">${remSec}s</span>
          </div>`;
        })
        .join("")
    : `<div class="muted small">Tidak ada server lock aktif.</div>`;
}

// Event Listeners
$("login-form").addEventListener("submit", (e) => {
  e.preventDefault();
  state.apiUrl = $("input-api-url").value.trim().replace(/\/+$/, "");
  state.accessKey = $("input-access-key").value.trim();
  tryUnlock();
});

$("btn-logout").addEventListener("click", lockDashboard);
$("btn-refresh").addEventListener("click", () => refreshDashboard(false));

document.querySelectorAll(".nav-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav-btn").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab-panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    $(`tab-${btn.dataset.tab}`).classList.add("active");
  });
});

document.querySelectorAll("[data-mass-cmd]").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const action = btn.dataset.massCmd;
    if (action === "remote_stop" && !confirm("Yakin hentikan SEMUA script yang berjalan?")) return;
    try {
      await apiFetch("/api/command", {
        method: "POST",
        body: JSON.stringify({ targetKey: "*", action }),
      });
      toast(`Perintah massal '${action}' dikirim!`);
    } catch (err) {
      toast(err.message, true);
    }
  });
});

document.querySelectorAll("[data-preset]").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const preset = PRESETS[btn.dataset.preset];
    if (!preset) return;
    try {
      await apiFetch("/api/config/global", {
        method: "PUT",
        body: JSON.stringify({ config: preset, replace: false }),
      });
      toast(`Preset '${btn.textContent.trim()}' diterapkan ke Global Config!`);
      await refreshDashboard(true);
    } catch (err) {
      toast(err.message, true);
    }
  });
});

$("instances-grid").addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-act]");
  if (!btn) return;
  const act = btn.dataset.act;
  const key = btn.dataset.key;
  const inst = (state.dashboard?.instances || []).find((x) => x.instanceKey === key);

  try {
    if (act === "cmd") {
      const cmd = btn.dataset.cmd;
      if (cmd === "remote_stop" && !confirm(`Stop script di akun ${inst?.playerName || key}?`)) return;
      await apiFetch("/api/command", {
        method: "POST",
        body: JSON.stringify({ targetKey: key, action: cmd }),
      });
      toast(`Perintah '${cmd}' dikirim ke ${inst?.playerName || key}`);
    } else if (act === "copy-join" && inst) {
      const snippet = `game:GetService("TeleportService"):TeleportToPlaceInstance(${inst.placeId}, "${inst.jobId}", game.Players.LocalPlayer)`;
      await navigator.clipboard.writeText(snippet);
      toast(`Snippet Teleport ke server ${inst.playerName} disalin!`);
    } else if (act === "edit-cfg") {
      state.configTarget = key;
      $("cfg-target-select").value = key;
      loadDraftConfigForTarget(key);
      document.querySelector('[data-tab="config"]').click();
    } else if (act === "open-inv") {
      document.querySelector('[data-tab="inventory"]').click();
    } else if (act === "delete") {
      await apiFetch(`/api/instance/${encodeURIComponent(key)}`, { method: "DELETE" });
      toast("Kartu instance offline dihapus.");
      refreshDashboard(false);
    } else if (act === "backup" && inst) {
      const others = (state.dashboard?.instances || []).filter((x) => x.online && x.instanceKey !== key);
      if (!others.length) {
        toast("Tidak ada instance online lain untuk dikirim!", true);
        return;
      }
      state.altRouteTarget = inst;
      $("alt-modal-desc").textContent = `Tujuan: server ${inst.playerName} (Place ${inst.placeId} • JobId ${inst.jobId}).`;
      $("alt-target-select").innerHTML = others
        .map((o) => `<option value="${escapeHtml(o.instanceKey)}">${escapeHtml(o.playerName)} (${escapeHtml(o.status)})</option>`)
        .join("");
      $("alt-modal").classList.remove("hidden");
    }
  } catch (err) {
    toast(err.message, true);
  }
});

$("btn-alt-cancel").addEventListener("click", () => $("alt-modal").classList.add("hidden"));
$("btn-alt-confirm").addEventListener("click", async () => {
  const dest = state.altRouteTarget;
  const senderKey = $("alt-target-select").value;
  if (!dest || !senderKey) return;
  try {
    await apiFetch("/api/command", {
      method: "POST",
      body: JSON.stringify({
        targetKey: senderKey,
        action: "join_server",
        payload: { placeId: dest.placeId, jobId: dest.jobId },
      }),
    });
    $("alt-modal").classList.add("hidden");
    toast(`Mengirim akun terpilih menuju server ${dest.playerName}!`);
  } catch (err) {
    toast(err.message, true);
  }
});

$("cfg-target-select").addEventListener("change", (e) => {
  state.configTarget = e.target.value;
  loadDraftConfigForTarget(state.configTarget);
});

$("btn-save-config").addEventListener("click", saveConfigToCloud);
$("btn-clear-override").addEventListener("click", async () => {
  if (state.configTarget === "__global__") return;
  try {
    await apiFetch(`/api/config/instance/${encodeURIComponent(state.configTarget)}`, {
      method: "PUT",
      body: JSON.stringify({ clear: true }),
    });
    toast("Override akun direset — kini mengikuti Global Config.");
    await refreshDashboard(true);
  } catch (err) {
    toast(err.message, true);
  }
});

$("cfg-rarities").addEventListener("click", (e) => {
  const pill = e.target.closest("[data-rarity-pill]");
  if (!pill) return;
  const r = pill.dataset.rarityPill;
  state.draftConfig.AllowedRarities[r] = !state.draftConfig.AllowedRarities[r];
  renderRarityPills();
});

$("btn-rarities-high").addEventListener("click", () => {
  state.draftConfig.AllowedRarities = { Mythical: true, Legendary: true, Rare: false, Uncommon: false, Common: false };
  renderRarityPills();
});
$("btn-rarities-all").addEventListener("click", () => {
  state.draftConfig.AllowedRarities = { Mythical: true, Legendary: true, Rare: true, Uncommon: true, Common: true };
  renderRarityPills();
});

$("fruit-search").addEventListener("input", renderFruitWatchlist);
$("cfg-fruits-grid").addEventListener("click", (e) => {
  const chip = e.target.closest("[data-fruit-id]");
  if (!chip) return;
  const id = chip.dataset.fruitId;
  state.draftConfig.TargetFruits[id] = !state.draftConfig.TargetFruits[id];
  renderFruitWatchlist();
});

$("btn-fruits-mythical").addEventListener("click", () => {
  state.draftConfig.TargetFruits = {};
  for (const f of FRUIT_CATALOG) {
    if (f.rarity === "Mythical") state.draftConfig.TargetFruits[f.id] = true;
  }
  renderFruitWatchlist();
});
$("btn-fruits-all").addEventListener("click", () => {
  state.draftConfig.TargetFruits = {};
  for (const f of FRUIT_CATALOG) state.draftConfig.TargetFruits[f.id] = true;
  renderFruitWatchlist();
});
$("btn-fruits-none").addEventListener("click", () => {
  state.draftConfig.TargetFruits = {};
  renderFruitWatchlist();
});

$("btn-clear-history").addEventListener("click", async () => {
  try {
    await apiFetch("/api/history", { method: "DELETE" });
    toast("Riwayat tangkapan dibersihkan.");
    refreshDashboard(false);
  } catch (err) {
    toast(err.message, true);
  }
});

$("fp-search").addEventListener("input", () => renderIntel(state.dashboard));

if ($("inv-search")) {
  $("inv-search").addEventListener("input", () => {
    if (state.dashboard) renderInventoryMatrix(state.dashboard.instances || [], state.dashboard.serverTime || Date.now());
  });
}
if ($("inv-only-online")) {
  $("inv-only-online").addEventListener("change", (e) => {
    state.invOnlyOnline = e.target.checked;
    if (state.dashboard) renderInventoryMatrix(state.dashboard.instances || [], state.dashboard.serverTime || Date.now());
  });
}
if ($("inv-rarity-filter")) {
  $("inv-rarity-filter").addEventListener("click", (e) => {
    const pill = e.target.closest("[data-inv-rarity]");
    if (!pill) return;
    state.invRarityFilter = pill.dataset.invRarity;
    document.querySelectorAll("[data-inv-rarity]").forEach((p) => {
      p.classList.toggle("active", p.dataset.invRarity === state.invRarityFilter);
    });
    if (state.dashboard) renderInventoryMatrix(state.dashboard.instances || [], state.dashboard.serverTime || Date.now());
  });
}

// 1-second live uptime ticker for all online instance cards & inventory headers
setInterval(() => {
  if ($("app-shell")?.classList.contains("hidden")) return;
  const nowServerMs = Date.now() + (state.serverOffsetMs || 0);
  document.querySelectorAll("[data-uptime-started]").forEach((el) => {
    if (el.dataset.uptimeOnline !== "1") return;
    const started = Number(el.dataset.uptimeStarted || 0);
    if (started > 0) {
      el.textContent = `⏱️ ${formatUptime(nowServerMs - started)}`;
    }
  });
}, 1000);
$("fp-list").addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-del-fp]");
  if (!btn) return;
  try {
    await apiFetch("/api/fingerprint", {
      method: "DELETE",
      body: JSON.stringify({ assetKey: btn.dataset.delFp }),
    });
    toast("Fingerprint dihapus dari Shared DB.");
    refreshDashboard(false);
  } catch (err) {
    toast(err.message, true);
  }
});

// Boot
parseUrlFragmentCreds();
$("input-api-url").value = state.apiUrl;
$("input-access-key").value = state.accessKey;
if (state.accessKey) {
  tryUnlock();
}
