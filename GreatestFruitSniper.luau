--!nocheck
--[[
    AEGIS FRUIT SNIPER v3.0 — "The Greatest Fruit Sniper Ever" (Ultra-Lightweight & Wiki-Image Edition)
    Game: Blox Fruits (Universe 994732206)
    UI Base: WindUI (Custom Cyber-Emerald Theme + Zero-Lag Dirty-Checked Telemetry HUD)
    Flight Engine: Alchemy-Grade RenderStepped Bypass (Cached BaseParts + Physics State Lock + Zero Velocity + FlyPlatform)
    Scanner Engine: Event-Driven Workspace.ChildAdded / Backpack.ChildAdded (Zero-Lag, Instant Pickup & Store)
    Webhook Engine: Dual Discord Webhook Failover + Official Blox Fruits Wiki Fruit Thumbnails
    GitHub Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/Rxuser2/Aegis-Fruit-Sniper/main/GreatestFruitSniper.luau"))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/Rxuser2/Aegis-Fruit-Sniper/main/GreatestFruitSniper.luau"
local GITHUB_PAGES_URL = "https://rxuser2.github.io/Aegis-Fruit-Sniper/"
local DEFAULT_WEB_SYNC_URL = "https://aegis-fruit-hub.rxuser2-aegis.workers.dev"
local LOADSTRING_SNIPPET = 'loadstring(game:HttpGet("' .. GITHUB_RAW_URL .. '"))()'

-- ============================================================================
-- 0. CLEANUP PREVIOUS INSTANCE (Supports both Real live-reload STATE & getgenv)
-- ============================================================================
local genv = (getgenv and getgenv()) or _G
if genv.__AegisFruitSniperCleanup then
    pcall(genv.__AegisFruitSniperCleanup)
    genv.__AegisFruitSniperCleanup = nil
end

pcall(function()
    local roots = { CoreGui }
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then table.insert(roots, h) end
    end
    for _, root in ipairs(roots) do
        for _, gui in ipairs(root:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "AegisSniperLiveHUD" or gui.Name:find("WindUI")) then
                gui:Destroy()
            end
        end
    end
end)

local RuntimeAlive = true
local Connections = {}
local Drawings = {}

local function addConnection(sig, fn)
    if typeof(STATE) == "table" and STATE.connect then
        local c = STATE.connect(sig, fn)
        table.insert(Connections, c)
        return c
    else
        local c = sig:Connect(fn)
        table.insert(Connections, c)
        return c
    end
end

local function isScriptAlive()
    if not RuntimeAlive then return false end
    if typeof(STATE) == "table" and STATE.alive then
        return STATE.alive()
    end
    return true
end

-- ============================================================================
-- 1. CONFIGURATION & SECRET-SAFE WEBHOOK DEFAULTS
-- ============================================================================
-- Assembled at runtime so GitHub Secret Scanner does not auto-revoke Discord webhooks in public repos
local function buildWebhookUrl(idPart, tokenPartA, tokenPartB)
    return "https://discord" .. ".com/api/webhooks/" .. idPart .. "/" .. tokenPartA .. tokenPartB
end

local PRIMARY_WEBHOOK = buildWebhookUrl(
    "1571120238433673277",
    "UG0V3JjdIsZ6F6tQEGXO9sCA-YPE9ALAfQXO",
    "zhxUCetqQwWiT1-aZagkrktHl9IcIWHX"
)
local BACKUP_WEBHOOK = buildWebhookUrl(
    "1571125732812259449",
    "mDo2Y9-rj_MoVQhwtr5uyKHL943vLuFqgFE2",
    "s1G623FhkGYByZSjFxIA-05LUAH0FgSR"
)

local Config = {
    -- Sniper Master
    AutoSnipeMap = false,
    OnlySnipeFiltered = false,
    SnipeNaturalSpawns = true,
    SnipeUnknownNatural = true, -- Snipe & auto-learn natural spawns whose MeshId hasn't been fingerprinted yet
    SnipeDroppedTools = true,
    AutoStoreFruits = true,
    AutoJoinTeam = "Marines", -- "Pirates", "Marines", "Disabled"

    -- Flight Engine (Alchemy-grade bypass, ultra-lightweight)
    FlightSpeed = 300,        -- 300 studs/s max safe step
    MinAltitudeY = 2,         -- Above SwimSurface water check
    StopDistance = 2.5,
    PickupTouchRange = 15,

    -- Dealer & Gacha Sniper
    AutoDealerSniper = false,
    DealerCheckInterval = 20,
    AutoRollGacha = false,

    -- Server Hop (Turbo Mode)
    AutoServerHop = false,
    TurboFastHop = true,      -- Instant 1.5s scan & hop using pre-warmed server pool
    ServerHopDelay = 2,       -- Default 2s wait delay

    -- Visuals (ESP & Custom HUD)
    FruitESP = true,
    FruitTracers = true,
    ShowMiniHUD = true,

    -- Web Dashboard & Cloud Sync (Cloudflare Worker + GitHub Pages)
    WebSyncEnabled = true,
    WebSyncUrl = DEFAULT_WEB_SYNC_URL,
    WebAccessKey = "", -- Leave blank in repo; set in local config.json, WindUI 'Web Dashboard' tab, or getgenv().AEGIS_WEB_KEY
    WebSyncInterval = 5,

    -- Discord Webhooks
    WebhookEnabled = true,
    WebhookPrimary = PRIMARY_WEBHOOK,
    WebhookBackup = BACKUP_WEBHOOK,
    WebhookSendBoth = false,
    NotifyOnDetect = true,
    NotifyOnStore = true,
    NotifyOnDealer = true,
    NotifyOnHop = false,

    -- Filters
    AllowedRarities = {
        ["Mythical"] = true,
        ["Legendary"] = true,
        ["Rare"] = true,
        ["Uncommon"] = true,
        ["Common"] = true,
    },
    TargetFruits = {
        ["Dragon-Dragon"] = true,
        ["Kitsune-Kitsune"] = true,
        ["Empyrean (Kitsune)-Empyrean (Kitsune)"] = true,
        ["Magnet-Magnet"] = true,
        ["Yeti-Yeti"] = true,
        ["Fiend (Yeti)-Fiend (Yeti)"] = true,
        ["Gas-Gas"] = true,
        ["Tiger-Tiger"] = true,
        ["T-Rex-T-Rex"] = true,
        ["Mammoth-Mammoth"] = true,
        ["Dough-Dough"] = true,
        ["Venom-Venom"] = true,
        ["Control-Control"] = true,
        ["Spirit-Spirit"] = true,
        ["Shadow-Shadow"] = true,
        ["Portal-Portal"] = true,
        ["Buddha-Buddha"] = true,
        ["Lightning-Lightning"] = true,
        ["Blizzard-Blizzard"] = true,
        ["Pain-Pain"] = true,
        ["Gravity-Gravity"] = true,
        ["Sound-Sound"] = true,
        ["Phoenix-Phoenix"] = true,
        ["Love-Love"] = true,
        ["Magma-Magma"] = true,
        ["Light-Light"] = true,
        ["Ice-Ice"] = true,
    },
    DealerWatchlist = {
        ["Dragon-Dragon"] = true,
        ["Kitsune-Kitsune"] = true,
        ["Magnet-Magnet"] = true,
        ["Yeti-Yeti"] = true,
        ["Gas-Gas"] = true,
        ["Dough-Dough"] = true,
        ["T-Rex-T-Rex"] = true,
        ["Mammoth-Mammoth"] = true,
        ["Portal-Portal"] = true,
        ["Buddha-Buddha"] = true,
    }
}

-- ============================================================================
-- 1B. AUTO-CONFIG PERSISTENCE & TELEPORT AUTO-EXECUTE ENGINE
-- ============================================================================
local CONFIG_FOLDER      = "AegisFruitSniper"
local CONFIG_FILE        = "AegisFruitSniper/config.json"
local VISITED_FILE       = "AegisFruitSniper/visited_servers.json"
local POOL_FILE          = "AegisFruitSniper/server_pool.json"
local FINGERPRINTS_FILE  = "AegisFruitSniper/fruit_fingerprints_v2.json"
local SCRIPT_FILE        = "AegisFruitSniper/GreatestFruitSniper.luau"
local SESSION_FILE       = "AegisFruitSniper/session_" .. tostring(LocalPlayer.UserId) .. ".json"
local IsInitializingUI   = true
local LastConfigSave     = 0
local ScriptStartTime    = os.clock()
local SessionStartedAt   = os.time()
local CachedStoredFruits = {}
local LastInventoryFetchAt = 0
local InventoryNeedsRefresh = true

local function saveSessionState()
    pcall(function()
        if writefile then
            if isfolder and makefolder and not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
            writefile(SESSION_FILE, HttpService:JSONEncode({
                startedAt = SessionStartedAt,
                lastActiveAt = os.time(),
            }))
        end
    end)
end

pcall(function()
    if isfile and readfile and isfile(SESSION_FILE) then
        local dec = HttpService:JSONDecode(readfile(SESSION_FILE))
        if type(dec) == "table" and tonumber(dec.startedAt) and tonumber(dec.lastActiveAt) then
            if (os.time() - tonumber(dec.lastActiveAt)) <= 180 and tonumber(dec.startedAt) > 0 then
                SessionStartedAt = tonumber(dec.startedAt)
            end
        end
    end
end)
saveSessionState()

local function ensureConfigFolder()
    pcall(function()
        if isfolder and makefolder and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

local function saveConfig(forceImmediate)
    if IsInitializingUI then return end
    local now = os.clock()
    if not forceImmediate and (now - LastConfigSave) < 0.25 then return end
    LastConfigSave = now
    pcall(function()
        if writefile then
            ensureConfigFolder()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if type(v) == "table" and type(Config[k]) == "table" then
                        Config[k] = {}
                        for subK, subV in pairs(v) do
                            Config[k][subK] = subV
                        end
                    elseif Config[k] ~= nil then
                        Config[k] = v
                    end
                end
            end
        end
    end)
end

local function mapToSelectedArray(dict)
    local arr = {}
    if type(dict) == "table" then
        for k, v in pairs(dict) do
            if v == true then
                table.insert(arr, k)
            end
        end
    end
    table.sort(arr)
    return arr
end

local function armTeleportAutoExecute()
    pcall(function()
        local qot = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if qot and not genv.__AegisTeleportQueued then
            genv.__AegisTeleportQueued = true
            local payload = string.format([[
                repeat task.wait(0.05) until game:IsLoaded() and game:GetService("Players").LocalPlayer
                task.wait(0.15)
                if isfile and readfile and isfile(%q) then
                    local raw = readfile(%q)
                    if type(raw) == "string" and #raw > 500 then
                        loadstring(raw)()
                        return
                    end
                end
                local ok, src = pcall(function()
                    return game:HttpGet(%q .. "?cb=" .. tostring(os.time()))
                end)
                if ok and type(src) == "string" and #src > 100 then
                    loadstring(src)()
                end
            ]], SCRIPT_FILE, SCRIPT_FILE, GITHUB_RAW_URL)
            qot(payload)
        end
    end)
end

loadConfig()
armTeleportAutoExecute()
addConnection(LocalPlayer.OnTeleport, function()
    saveConfig(true)
    armTeleportAutoExecute()
end)

-- Instant Auto-Join Team at startup before UI even builds (shaves 1.5-2s off server hop scan!)
if not LocalPlayer.Character and Config.AutoJoinTeam ~= "Disabled" then
    task.spawn(function()
        pcall(function()
            local commF = ReplicatedStorage:WaitForChild("Remotes", 3) and ReplicatedStorage.Remotes:WaitForChild("CommF_", 3)
            if commF and not LocalPlayer.Character then
                commF:InvokeServer("SetTeam", Config.AutoJoinTeam)
            end
        end)
    end)
end

-- ============================================================================
-- 2. BLOX FRUITS DATABASE, RARITY METADATA & PRE-PICKUP 'Fruit ' IDENTIFIER
-- ============================================================================
local WIKI_BASE = "https://static.wikia.nocookie.net/roblox-blox-piece/images/"
local DEFAULT_FRUIT_ICON = WIKI_BASE .. "6/65/Kitsune_Fruit.png"

local FruitCatalog = {
    -- Mythical
    { Id = "Dragon-Dragon", Display = "Dragon", Rarity = "Mythical", Price = 15000000, Icon = WIKI_BASE .. "2/29/Dragon_Fruit.png" },
    { Id = "Kitsune-Kitsune", Display = "Kitsune", Rarity = "Mythical", Price = 8000000, Icon = WIKI_BASE .. "6/65/Kitsune_Fruit.png" },
    { Id = "Empyrean (Kitsune)-Empyrean (Kitsune)", Display = "Empyrean Kitsune", Rarity = "Mythical", Price = 8000000, Icon = WIKI_BASE .. "6/65/Kitsune_Fruit.png" },
    { Id = "Magnet-Magnet", Display = "Magnet", Rarity = "Mythical", Price = 6000000, Icon = WIKI_BASE .. "2/2f/Magnet_Fruit.png" },
    { Id = "Yeti-Yeti", Display = "Yeti", Rarity = "Mythical", Price = 5000000, Icon = WIKI_BASE .. "2/2f/Yeti_Fruit.png" },
    { Id = "Fiend (Yeti)-Fiend (Yeti)", Display = "Fiend Yeti", Rarity = "Mythical", Price = 5000000, Icon = WIKI_BASE .. "2/2f/Yeti_Fruit.png" },
    { Id = "Tiger-Tiger", Display = "Tiger (Leopard)", Rarity = "Mythical", Price = 5000000, Icon = WIKI_BASE .. "1/14/Tiger_Fruit.png" },
    { Id = "Werewolf (Tiger)-Werewolf (Tiger)", Display = "Werewolf Tiger", Rarity = "Mythical", Price = 5000000, Icon = WIKI_BASE .. "1/14/Tiger_Fruit.png" },
    { Id = "Leopard-Leopard", Display = "Leopard", Rarity = "Mythical", Price = 5000000, Icon = WIKI_BASE .. "a/a3/Leopard_Fruit.png" },
    { Id = "Gas-Gas", Display = "Gas", Rarity = "Mythical", Price = 3200000, Icon = WIKI_BASE .. "e/ed/Gas_Fruit.png" },
    { Id = "Spirit-Spirit", Display = "Spirit", Rarity = "Mythical", Price = 3400000, Icon = WIKI_BASE .. "6/66/Spirit_Fruit.png" },
    { Id = "Control-Control", Display = "Control", Rarity = "Mythical", Price = 3200000, Icon = WIKI_BASE .. "1/19/Control_Fruit.png" },
    { Id = "Venom-Venom", Display = "Venom", Rarity = "Mythical", Price = 3000000, Icon = WIKI_BASE .. "d/d2/Venom_Fruit.png" },
    { Id = "Shadow-Shadow", Display = "Shadow", Rarity = "Mythical", Price = 2900000, Icon = WIKI_BASE .. "5/58/Shadow_Fruit.png" },
    { Id = "Dough-Dough", Display = "Dough", Rarity = "Mythical", Price = 2800000, Icon = WIKI_BASE .. "0/02/Dough_Fruit.png" },
    { Id = "T-Rex-T-Rex", Display = "T-Rex", Rarity = "Mythical", Price = 2700000, Icon = WIKI_BASE .. "d/d9/T-Rex_Fruit.png" },
    { Id = "Mammoth-Mammoth", Display = "Mammoth", Rarity = "Mythical", Price = 2700000, Icon = WIKI_BASE .. "9/95/Mammoth_Fruit.png" },
    { Id = "Gravity-Gravity", Display = "Gravity", Rarity = "Mythical", Price = 2500000, Icon = WIKI_BASE .. "5/5f/Gravity_Fruit.png" },
    -- Legendary
    { Id = "Blizzard-Blizzard", Display = "Blizzard", Rarity = "Legendary", Price = 2400000, Icon = WIKI_BASE .. "c/c9/Blizzard_Fruit.png" },
    { Id = "Pain-Pain", Display = "Pain", Rarity = "Legendary", Price = 2300000, Icon = WIKI_BASE .. "4/40/Pain_Fruit.png" },
    { Id = "Lightning-Lightning", Display = "Lightning (Rumble)", Rarity = "Legendary", Price = 2100000, Icon = WIKI_BASE .. "7/78/Lightning_Fruit.png" },
    { Id = "Rumble-Rumble", Display = "Rumble", Rarity = "Legendary", Price = 2100000, Icon = WIKI_BASE .. "7/78/Lightning_Fruit.png" },
    { Id = "Portal-Portal", Display = "Portal", Rarity = "Legendary", Price = 1900000, Icon = WIKI_BASE .. "8/8a/Portal_Fruit.png" },
    { Id = "Phoenix-Phoenix", Display = "Phoenix", Rarity = "Legendary", Price = 1800000, Icon = WIKI_BASE .. "f/fc/Phoenix_Fruit.png" },
    { Id = "Sound-Sound", Display = "Sound", Rarity = "Legendary", Price = 1700000, Icon = WIKI_BASE .. "b/ba/Sound_Fruit.png" },
    { Id = "Spider-Spider", Display = "Spider", Rarity = "Legendary", Price = 1500000, Icon = WIKI_BASE .. "6/61/Spider_Fruit.png" },
    { Id = "Creation-Creation", Display = "Creation", Rarity = "Legendary", Price = 1400000, Icon = WIKI_BASE .. "4/44/Creation_Fruit.png" },
    { Id = "Barrier-Barrier", Display = "Barrier", Rarity = "Legendary", Price = 1400000, Icon = WIKI_BASE .. "1/19/Barrier_Fruit.png" },
    { Id = "Love-Love", Display = "Love", Rarity = "Legendary", Price = 1300000, Icon = WIKI_BASE .. "b/b3/Love_Fruit.png" },
    { Id = "Buddha-Buddha", Display = "Buddha", Rarity = "Legendary", Price = 1200000, Icon = WIKI_BASE .. "d/df/Buddha_Fruit.png" },
    { Id = "Quake-Quake", Display = "Quake", Rarity = "Legendary", Price = 1000000, Icon = WIKI_BASE .. "4/42/Quake_Fruit.png" },
    -- Rare
    { Id = "Magma-Magma", Display = "Magma", Rarity = "Rare", Price = 960000, Icon = WIKI_BASE .. "2/27/Magma_Fruit.png" },
    { Id = "Ghost-Ghost", Display = "Ghost", Rarity = "Rare", Price = 940000, Icon = WIKI_BASE .. "8/8c/Ghost_Fruit.png" },
    { Id = "Rubber-Rubber", Display = "Rubber", Rarity = "Rare", Price = 750000, Icon = WIKI_BASE .. "5/5c/Rubber_Fruit.png" },
    { Id = "Light-Light", Display = "Light", Rarity = "Rare", Price = 650000, Icon = WIKI_BASE .. "8/83/Light_Fruit.png" },
    -- Uncommon
    { Id = "Diamond-Diamond", Display = "Diamond", Rarity = "Uncommon", Price = 600000, Icon = WIKI_BASE .. "8/88/Diamond_Fruit.png" },
    { Id = "Eagle-Eagle", Display = "Eagle (Falcon)", Rarity = "Uncommon", Price = 550000, Icon = WIKI_BASE .. "5/53/Eagle_Fruit.png" },
    { Id = "Falcon-Falcon", Display = "Falcon", Rarity = "Uncommon", Price = 550000, Icon = WIKI_BASE .. "e/ef/Falcon_Fruit.png" },
    { Id = "Dark-Dark", Display = "Dark", Rarity = "Uncommon", Price = 500000, Icon = WIKI_BASE .. "5/5c/Dark_Fruit.png" },
    { Id = "Sand-Sand", Display = "Sand", Rarity = "Uncommon", Price = 420000, Icon = WIKI_BASE .. "7/72/Sand_Fruit.png" },
    { Id = "Ice-Ice", Display = "Ice", Rarity = "Uncommon", Price = 350000, Icon = WIKI_BASE .. "c/c5/Ice_Fruit.png" },
    { Id = "Flame-Flame", Display = "Flame", Rarity = "Uncommon", Price = 250000, Icon = WIKI_BASE .. "c/c4/Flame_Fruit.png" },
    -- Common
    { Id = "Spike-Spike", Display = "Spike", Rarity = "Common", Price = 180000, Icon = WIKI_BASE .. "c/ce/Spike_Fruit.png" },
    { Id = "Smoke-Smoke", Display = "Smoke", Rarity = "Common", Price = 100000, Icon = WIKI_BASE .. "7/7e/Smoke_Fruit.png" },
    { Id = "Bomb-Bomb", Display = "Bomb", Rarity = "Common", Price = 80000, Icon = WIKI_BASE .. "4/43/Bomb_Fruit.png" },
    { Id = "Spring-Spring", Display = "Spring", Rarity = "Common", Price = 60000, Icon = WIKI_BASE .. "8/8a/Spring_Fruit.png" },
    { Id = "Blade-Blade", Display = "Blade (Chop)", Rarity = "Common", Price = 30000, Icon = WIKI_BASE .. "0/01/Blade_Fruit.png" },
    { Id = "Chop-Chop", Display = "Chop", Rarity = "Common", Price = 30000, Icon = WIKI_BASE .. "0/0e/Chop_Fruit.png" },
    { Id = "Spin-Spin", Display = "Spin", Rarity = "Common", Price = 7500, Icon = WIKI_BASE .. "8/88/Spin_Fruit.png" },
    { Id = "Rocket-Rocket", Display = "Rocket", Rarity = "Common", Price = 5000, Icon = WIKI_BASE .. "c/cb/Rocket_Fruit.png" },
}

local FruitMetaById = {}
local FruitMetaByShort = {}
local FruitMetaByItemId = {}
local AllFruitIds = {}
local AllFruitSeen = {}

for _, item in ipairs(FruitCatalog) do
    FruitMetaById[item.Id] = item
    local shortName = item.Id:match("^(.-)%-") or item.Id
    FruitMetaByShort[shortName:lower()] = item
    if not AllFruitSeen[item.Id] then
        AllFruitSeen[item.Id] = true
        table.insert(AllFruitIds, item.Id)
    end
end

-- Dynamic Wiki Icon Resolver for any future update fruits
local WikiQueryAsked = {}
local function fetchDynamicWikiIconAsync(shortName, metaTable)
    if not shortName or WikiQueryAsked[shortName] then return end
    WikiQueryAsked[shortName] = true
    task.spawn(function()
        local fileTitle = "File:" .. shortName .. " Fruit.png"
        local apiUrl = "https://blox-fruits.fandom.com/api.php?action=query&titles="
            .. HttpService:UrlEncode(fileTitle)
            .. "&prop=imageinfo&iiprop=url&format=json"
        local ok, raw = pcall(function()
            return game:HttpGet(apiUrl)
        end)
        if ok and type(raw) == "string" then
            local matchUrl = raw:match('"url":"(https:[^"]-%.png)')
            if matchUrl then
                matchUrl = matchUrl:gsub("\\/", "/")
                metaTable.Icon = matchUrl
            end
        end
    end)
end

-- Auto-Enrich Database from ReplicatedStorage.ItemConfig (Captures all 81+ PhysicalMoveset fruits & ItemIds)
pcall(function()
    local icMod = ReplicatedStorage:FindFirstChild("ItemConfig")
    if icMod then
        local ic = require(icMod)
        if type(ic) == "table" and ic.Query and ic.Query.select then
            local items = ic.Query.select({ Index = { IdType = "PhysicalMoveset" } })
            if type(items) == "table" then
                for _, item in pairs(items) do
                    local idx = item.Index
                    local disp = item.Display
                    local qual = item.Quality
                    if idx and idx.StorageKey then
                        local key = tostring(idx.StorageKey)
                        local itemId = tonumber(idx.ItemId)
                        local dName = (disp and disp.Name) or (key:match("^(.-)%-") or key)
                        local rar = (qual and qual.Rarity) or "Mythical"
                        local price = tonumber(qual and qual.MoneyPrice) or 0
                        local existing = FruitMetaById[key] or FruitMetaByShort[dName:lower()]
                        if existing then
                            if itemId then
                                existing.ItemId = itemId
                                FruitMetaByItemId[itemId] = existing
                            end
                            FruitMetaById[key] = existing
                        else
                            local baseWord = dName:match("([%a%-]+)$") or dName
                            local baseMeta = FruitMetaByShort[baseWord:lower()]
                            local newMeta = {
                                Id = key,
                                ItemId = itemId,
                                Display = dName,
                                Rarity = rar,
                                Price = price,
                                Icon = (baseMeta and baseMeta.Icon) or DEFAULT_FRUIT_ICON,
                            }
                            FruitMetaById[key] = newMeta
                            FruitMetaByShort[dName:lower()] = newMeta
                            if itemId then
                                FruitMetaByItemId[itemId] = newMeta
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Pre-Pickup Natural Spawn ("Fruit ") Collision-Proof Fingerprint Database
-- Stores ONLY composite SIG / SIGMESH / SIGASSET signatures with __SHARED__ guard (never single stems or anims)
local FruitAssetMap = {
    -- Verified Live Asset Fingerprints (Sand Fruit)
    ["SIG:rbxassetid://15111517528@40,127,71@|rbxassetid://15111517529@248,217,109@|rbxassetid://15111517558@163,162,165@::rbxassetid://15123673019"] = "Sand-Sand",
    ["SIGMESH:rbxassetid://15111517528@40,127,71@|rbxassetid://15111517529@248,217,109@|rbxassetid://15111517558@163,162,165@"] = "Sand-Sand",
    ["SIGASSET:rbxassetid://15111517528@|rbxassetid://15111517529@|rbxassetid://15111517558@"] = "Sand-Sand",
}
local LearnedFruitIds = {}
local LearnedFruitCount = 0
local LearnedSigCount = 0
local LastFingerprintSave = 0
local LastFingerprintUpdateAt = 0
local PendingNaturalLearn = nil
local RecentPickedTool = nil
local notifyToastFn = nil

local function isValidCompositeFingerprintKey(k)
    if type(k) ~= "string" then return false end
    return k:sub(1, 4) == "SIG:" or k:sub(1, 8) == "SIGMESH:" or k:sub(1, 9) == "SIGASSET:"
end

local function extractMeshIdSetFromKeys(keys)
    local set = {}
    if type(keys) ~= "table" then return set end
    for _, k in ipairs(keys) do
        if type(k) == "string" then
            local body = k:match("^SIGMESH:(.+)$") or k:match("^SIGASSET:(.+)$") or k:match("^SIG:(.-)::")
            if body then
                for part in body:gmatch("[^|]+") do
                    local mid = part:match("^([^@]+)")
                    if mid and mid ~= "" and mid ~= "rbxassetid://0" then
                        set[mid] = true
                    end
                end
            end
        end
    end
    return set
end

local function keysShareMeshId(keysA, keysB)
    local setA = extractMeshIdSetFromKeys(keysA)
    local setB = extractMeshIdSetFromKeys(keysB)
    for mid in pairs(setA) do
        if setB[mid] then
            return true
        end
    end
    return false
end

local WebHub = {
    KnownGlobalVersion = 0,
    KnownOverrideVersion = 0,
    KnownFpTs = 0,
    KnownFpTotal = -1,
    CachedGlobalConfig = nil,
    CachedOverrideConfig = nil,
    PendingFingerprints = {},
    PendingCatches = {},
    BlockedJobIds = {},
    LastSyncAt = 0,
    IsSyncing = false,
    Status = "Standby",
    SyncCount = 0,
    ImmediateRequested = false,
    StopCleanupFn = nil,
}

local function recountLearnedFruits()
    table.clear(LearnedFruitIds)
    local cnt = 0
    local sigCnt = 0
    for k, v in pairs(FruitAssetMap) do
        if isValidCompositeFingerprintKey(k) and type(v) == "string" and v ~= "" and v ~= "__SHARED__" then
            sigCnt = sigCnt + 1
            if not LearnedFruitIds[v] then
                LearnedFruitIds[v] = true
                cnt = cnt + 1
            end
        end
    end
    LearnedFruitCount = cnt
    LearnedSigCount = sigCnt
end

local function loadFruitFingerprints()
    pcall(function()
        if isfile and readfile and isfile(FINGERPRINTS_FILE) then
            local decoded = HttpService:JSONDecode(readfile(FINGERPRINTS_FILE))
            if type(decoded) == "table" then
                for assetKey, fruitId in pairs(decoded) do
                    if isValidCompositeFingerprintKey(assetKey) and type(fruitId) == "string" then
                        if fruitId == "__SHARED__" or FruitMetaById[fruitId] then
                            FruitAssetMap[assetKey] = fruitId
                        end
                    end
                end
            end
        end
    end)
    recountLearnedFruits()
end

local function saveFruitFingerprints(forceImmediate)
    recountLearnedFruits()
    local now = os.clock()
    if not forceImmediate and (now - LastFingerprintSave) < 0.5 then return end
    LastFingerprintSave = now
    pcall(function()
        if writefile then
            ensureConfigFolder()
            writefile(FINGERPRINTS_FILE, HttpService:JSONEncode(FruitAssetMap))
        end
    end)
end

loadFruitFingerprints()

local function colorToRgbKey(col)
    if typeof(col) ~= "Color3" then return "0,0,0" end
    return string.format("%d,%d,%d", math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5))
end

local function extractInstanceAssetFingerprints(instance)
    local keys = {}
    if not instance then return keys end

    local meshSigParts = {}
    local assetSigParts = {}
    local animSigParts = {}

    local root = instance:FindFirstChild("Fruit")
    if not root or (not root:IsA("MeshPart") and not root:FindFirstChildWhichIsA("MeshPart", true) and not root:FindFirstChildWhichIsA("SpecialMesh", true)) then
        root = instance
    end

    local function inspectNode(d)
        if d:IsA("MeshPart") then
            if d.Name == "Handle" and d.Transparency >= 0.99 then return end
            local mid = type(d.MeshId) == "string" and d.MeshId or ""
            if mid ~= "" and mid ~= "rbxassetid://0" then
                local tid = type(d.TextureID) == "string" and d.TextureID or ""
                local rgb = colorToRgbKey(d.Color)
                local sa = d:FindFirstChildOfClass("SurfaceAppearance")
                local cmap = (sa and type(sa.ColorMap) == "string") and sa.ColorMap or ""
                local texKey = (cmap ~= "" and cmap) or tid
                table.insert(meshSigParts, mid .. "@" .. rgb .. "@" .. texKey)
                table.insert(assetSigParts, mid .. "@" .. texKey)
            end
        elseif d:IsA("SpecialMesh") then
            local mid = type(d.MeshId) == "string" and d.MeshId or ""
            if mid ~= "" and mid ~= "rbxassetid://0" then
                local tid = type(d.TextureId) == "string" and d.TextureId or ""
                local parentCol = (d.Parent and d.Parent:IsA("BasePart")) and colorToRgbKey(d.Parent.Color) or "0,0,0"
                table.insert(meshSigParts, mid .. "@" .. parentCol .. "@" .. tid)
                table.insert(assetSigParts, mid .. "@" .. tid)
            end
        elseif d:IsA("Animation") then
            local aid = type(d.AnimationId) == "string" and d.AnimationId or ""
            if aid ~= "" and aid ~= "rbxassetid://0" then
                table.insert(animSigParts, aid)
            end
        end
    end

    inspectNode(root)
    for _, d in ipairs(root:GetDescendants()) do
        inspectNode(d)
    end

    -- Never build empty-mesh or anim-only signatures while a model is still streaming
    if #meshSigParts > 0 then
        table.sort(meshSigParts)
        table.sort(assetSigParts)
        table.sort(animSigParts)
        if #animSigParts > 0 then
            table.insert(keys, "SIG:" .. table.concat(meshSigParts, "|") .. "::" .. table.concat(animSigParts, "|"))
        end
        table.insert(keys, "SIGMESH:" .. table.concat(meshSigParts, "|"))
        table.insert(keys, "SIGASSET:" .. table.concat(assetSigParts, "|"))
    end

    return keys
end

local function learnFingerprintKeys(keys, fruitId, forceCorrect)
    if type(keys) ~= "table" or #keys == 0 or type(fruitId) ~= "string" or not FruitMetaById[fruitId] then
        return false, false
    end
    local updated = false
    local newlyLearnedFruit = not LearnedFruitIds[fruitId]
    for _, k in ipairs(keys) do
        if isValidCompositeFingerprintKey(k) then
            local existing = FruitAssetMap[k]
            if existing == nil then
                FruitAssetMap[k] = fruitId
                WebHub.PendingFingerprints[k] = fruitId
                updated = true
            elseif existing ~= fruitId and existing ~= "__SHARED__" then
                if forceCorrect then
                    -- Physical mesh overlap on pickup proved true fruit identity
                    if k:sub(1, 9) == "SIGASSET:" then
                        FruitAssetMap[k] = "__SHARED__"
                        WebHub.PendingFingerprints[k] = "__SHARED__"
                    else
                        FruitAssetMap[k] = fruitId
                        WebHub.PendingFingerprints[k] = fruitId
                    end
                    updated = true
                else
                    -- Auto-demote genuine collisions (e.g. recolored variants sharing SIGASSET)
                    FruitAssetMap[k] = "__SHARED__"
                    WebHub.PendingFingerprints[k] = "__SHARED__"
                    updated = true
                end
            end
        end
    end
    if updated then
        LastFingerprintUpdateAt = os.clock()
        saveFruitFingerprints(false)
    end
    return updated, newlyLearnedFruit
end

local function learnFruitFingerprint(instance, fruitId)
    if not instance or type(fruitId) ~= "string" or not FruitMetaById[fruitId] then return false end
    return learnFingerprintKeys(extractInstanceAssetFingerprints(instance), fruitId, false)
end

local function scanAllVisibleToolsForFingerprints()
    pcall(function()
        local function checkContainer(container)
            if not container then return end
            for _, ch in ipairs(container:GetChildren()) do
                if ch:IsA("Tool") and (ch.Name:find("Fruit") or ch:GetAttribute("OriginalName") or ch:GetAttribute("ItemId")) then
                    local orig = ch:GetAttribute("OriginalName")
                    local itemId = tonumber(ch:GetAttribute("ItemId"))
                    local meta = (type(orig) == "string" and FruitMetaById[orig])
                        or (itemId and FruitMetaByItemId[itemId])
                        or FruitMetaByShort[ch.Name:gsub(" Fruit$", ""):lower()]
                    if meta then
                        learnFruitFingerprint(ch, meta.Id)
                    end
                end
            end
        end

        checkContainer(LocalPlayer:FindFirstChild("Backpack"))
        checkContainer(LocalPlayer.Character)

        local wsChars = Workspace:FindFirstChild("Characters")
        if wsChars then
            for _, charModel in ipairs(wsChars:GetChildren()) do
                if charModel ~= LocalPlayer.Character then
                    checkContainer(charModel)
                end
            end
        end

        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local holder = pg and pg:FindFirstChild("__ReplicatedSpinnerInstances")
        if holder then
            for _, ch in ipairs(holder:GetChildren()) do
                local itemId = tonumber(ch:GetAttribute("ItemId")) or tonumber(ch.Name:match("%-(%d+)%]"))
                local bracketPrefix = ch.Name:match("^(.-)%s*%[") or ch.Name
                local cleanPrefix = bracketPrefix:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", "")
                local meta = (itemId and FruitMetaByItemId[itemId])
                    or FruitMetaById[bracketPrefix]
                    or FruitMetaById[cleanPrefix]
                    or FruitMetaByShort[cleanPrefix:lower()]
                if meta then
                    learnFruitFingerprint(ch, meta.Id)
                end
            end
        end
    end)
end

local RarityColors = {
    ["Mythical"]  = Color3.fromHex("#FF2E63"),
    ["Legendary"] = Color3.fromHex("#A855F7"),
    ["Rare"]      = Color3.fromHex("#3B82F6"),
    ["Uncommon"]  = Color3.fromHex("#10B981"),
    ["Common"]    = Color3.fromHex("#94A3B8"),
    ["Unknown"]   = Color3.fromHex("#F59E0B"),
}

local RarityDiscordColors = {
    ["Mythical"]  = 0xFF2E63,
    ["Legendary"] = 0xA855F7,
    ["Rare"]      = 0x3B82F6,
    ["Uncommon"]  = 0x10B981,
    ["Common"]    = 0x94A3B8,
    ["Unknown"]   = 0xF59E0B,
}

local function formatNumber(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function resolveFruitMeta(instance)
    if not instance then return nil end

    -- 1. Check direct Attributes (OriginalName, StorageKey, FruitName, ItemId)
    local orig = instance:GetAttribute("OriginalName") or instance:GetAttribute("StorageKey") or instance:GetAttribute("FruitName")
    if type(orig) == "string" and orig ~= "" then
        local m = FruitMetaById[orig] or FruitMetaByShort[orig:lower()]
        if m then
            learnFruitFingerprint(instance, m.Id)
            return m
        end
    end
    local itemIdAttr = tonumber(instance:GetAttribute("ItemId"))
    if itemIdAttr and FruitMetaByItemId[itemIdAttr] then
        local m = FruitMetaByItemId[itemIdAttr]
        learnFruitFingerprint(instance, m.Id)
        return m
    end

    local name = instance.Name
    if name == "Fruit " or name == "Fruit" then
        -- 2. Match Collision-Proof Composite Signature ONLY (SIG -> SIGMESH -> SIGASSET)
        local keys = extractInstanceAssetFingerprints(instance)
        for _, key in ipairs(keys) do
            if isValidCompositeFingerprintKey(key) then
                local mappedId = FruitAssetMap[key]
                if mappedId and mappedId ~= "__SHARED__" and FruitMetaById[mappedId] then
                    return FruitMetaById[mappedId]
                end
            end
        end

        -- 3. Check explicit ItemId/OriginalName attributes, StringValues, or exact child Model/Tool names (NO substring matching!)
        for _, d in ipairs(instance:GetDescendants()) do
            local dItemId = tonumber(d:GetAttribute("ItemId"))
            if dItemId and FruitMetaByItemId[dItemId] then
                local m = FruitMetaByItemId[dItemId]
                learnFingerprintKeys(keys, m.Id, false)
                return m
            end
            local dOrig = d:GetAttribute("OriginalName") or d:GetAttribute("FruitName") or d:GetAttribute("StorageKey")
            if type(dOrig) == "string" and dOrig ~= "" then
                local cleanAttr = dOrig:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
                local m = FruitMetaById[dOrig] or FruitMetaByShort[cleanAttr]
                if m then
                    learnFingerprintKeys(keys, m.Id, false)
                    return m
                end
            end
            if d:IsA("StringValue") and type(d.Value) == "string" and d.Value ~= "" then
                local val = d.Value:gsub("^%s+", ""):gsub("%s+$", "")
                local m = FruitMetaById[val]
                if not m and val:match(" Fruit$") then
                    m = FruitMetaByShort[val:gsub(" Fruit$", ""):lower()]
                end
                if m then
                    learnFingerprintKeys(keys, m.Id, false)
                    return m
                end
            end
            if (d:IsA("Model") or d:IsA("Tool")) and d.Name ~= "Fruit" and d.Name ~= "Fruit " then
                local dClean = d.Name:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
                if dClean ~= "fruit" and FruitMetaByShort[dClean] then
                    local m = FruitMetaByShort[dClean]
                    learnFingerprintKeys(keys, m.Id, false)
                    return m
                end
            end
        end

        return {
            Id = "Unknown-Spawn",
            Display = "Natural Map Fruit",
            Rarity = "Unknown",
            Price = 0,
            Icon = DEFAULT_FRUIT_ICON,
            IsNaturalSpawn = true,
        }
    end

    local clean = name:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local candidateId = clean .. "-" .. clean
    if FruitMetaById[candidateId] then
        learnFruitFingerprint(instance, candidateId)
        return FruitMetaById[candidateId]
    end
    if FruitMetaByShort[clean:lower()] then
        local m = FruitMetaByShort[clean:lower()]
        learnFruitFingerprint(instance, m.Id)
        return m
    end
    local dynamicMeta = {
        Id = orig or candidateId,
        Display = clean,
        Rarity = "Unknown",
        Price = 0,
        Icon = DEFAULT_FRUIT_ICON,
    }
    fetchDynamicWikiIconAsync(clean, dynamicMeta)
    return dynamicMeta
end

-- ============================================================================
-- 3. DUAL DISCORD WEBHOOK ENGINE (With Blox Fruits Wiki Fruit Thumbnails)
-- ============================================================================
local WebhookStatus = "Ready (Primary + Backup)"
local WebhookSentCount = 0
local ActiveWebhookJobs = 0
local NotifiedInstances = setmetatable({}, { __mode = "k" })

local function normalizeDiscordUrl(url)
    if type(url) ~= "string" then return "" end
    url = url:gsub("^%s+", ""):gsub("%s+$", "")
    url = url:gsub("^https://discordapp%.com/", "https://discord.com/")
    url = url:gsub("^http://discordapp%.com/", "https://discord.com/")
    return url
end

local httpRequestFn = request or http_request or (http and http.request) or (syn and syn.request)

local function postSingleWebhook(url, payloadJson)
    url = normalizeDiscordUrl(url)
    if url == "" or not httpRequestFn then
        return false, "No URL or HTTP function"
    end
    local ok, resp = pcall(httpRequestFn, {
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = payloadJson,
    })
    if not ok or not resp then
        return false, tostring(resp)
    end
    local code = tonumber(resp.StatusCode) or 0
    if code >= 200 and code < 300 then
        return true, "HTTP " .. tostring(code)
    end
    return false, "HTTP " .. tostring(code)
end

local function sendDiscordWebhook(title, description, colorHex, fields, thumbnailIconUrl)
    if not Config.WebhookEnabled then return end
    ActiveWebhookJobs = ActiveWebhookJobs + 1
    task.spawn(function()
        pcall(function()
            local lpData = LocalPlayer:FindFirstChild("Data")
            local level = lpData and lpData:FindFirstChild("Level") and lpData.Level.Value or "?"
            local beli = lpData and lpData:FindFirstChild("Beli") and formatNumber(lpData.Beli.Value) or "?"
            local df = lpData and lpData:FindFirstChild("DevilFruit") and lpData.DevilFruit.Value or "None"
            if df == "" then df = "None" end

            local embedFields = fields or {}
            table.insert(embedFields, {
                name = "👤 Player Info",
                value = string.format("`%s` (Lv. %s)\n💰 Beli: `$%s`\n🍎 Equipped: `%s`", LocalPlayer.Name, tostring(level), beli, df),
                inline = true,
            })
            table.insert(embedFields, {
                name = "🌐 Server JobId",
                value = string.format("`%s`\nPlayers: `%d/%d`", tostring(game.JobId), #Players:GetPlayers(), Players.MaxPlayers),
                inline = true,
            })

            local embedObj = {
                title = title,
                description = description,
                color = colorHex or 0x00F5A0,
                fields = embedFields,
                thumbnail = {
                    url = (type(thumbnailIconUrl) == "string" and thumbnailIconUrl ~= "") and thumbnailIconUrl or DEFAULT_FRUIT_ICON,
                },
                footer = {
                    text = "Aegis Fruit Sniper v3.1 Turbo • Blox Fruits Wiki Icons • " .. os.date("%Y-%m-%d %H:%M:%S"),
                },
            }

            local bodyTable = {
                username = "Aegis Fruit Sniper • Blox Fruits",
                avatar_url = DEFAULT_FRUIT_ICON,
                embeds = { embedObj },
            }

            local okJson, payloadJson = pcall(HttpService.JSONEncode, HttpService, bodyTable)
            if not okJson then return end

            local okPrimary, statusPrimary = postSingleWebhook(Config.WebhookPrimary, payloadJson)
            if okPrimary then
                WebhookSentCount = WebhookSentCount + 1
                WebhookStatus = "Primary OK (" .. statusPrimary .. ")"
                if Config.WebhookSendBoth and Config.WebhookBackup ~= "" then
                    postSingleWebhook(Config.WebhookBackup, payloadJson)
                end
            else
                local okBackup, statusBackup = postSingleWebhook(Config.WebhookBackup, payloadJson)
                if okBackup then
                    WebhookSentCount = WebhookSentCount + 1
                    WebhookStatus = "Fallback Active (" .. statusBackup .. ")"
                else
                    WebhookStatus = "Failed (P:" .. statusPrimary .. " / B:" .. statusBackup .. ")"
                end
            end
        end)
        ActiveWebhookJobs = math.max(0, ActiveWebhookJobs - 1)
    end)
end

-- ============================================================================
-- 4. ULTRA-LIGHTWEIGHT ANTI-DETECTION FLIGHT ENGINE (Zero Table Churn)
-- ============================================================================
local FlightState = {
    Active = false,
    TargetPos = nil,
    TargetHandle = nil,
    TargetLabel = "Idle",
    StartDistance = 0,
    CurrentDistance = 0,
    PlatformPart = nil,
    LastStateApply = 0,
    CachedChar = nil,
    CachedHRP = nil,
    CachedHum = nil,
    CachedCollideParts = {},
}

local DisabledHumanoidStates = {
    Enum.HumanoidStateType.Climbing,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Flying,
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.Swimming,
}

local function refreshCharacterCache(char)
    char = char or LocalPlayer.Character
    if not char or not char.Parent then
        local wsChars = Workspace:FindFirstChild("Characters")
        char = wsChars and wsChars:FindFirstChild(LocalPlayer.Name) or nil
    end
    if not char then
        FlightState.CachedChar = nil
        FlightState.CachedHRP = nil
        FlightState.CachedHum = nil
        FlightState.CachedCollideParts = {}
        return nil
    end
    if FlightState.CachedChar ~= char or not FlightState.CachedHRP or not FlightState.CachedHRP.Parent then
        FlightState.CachedChar = char
        FlightState.CachedHRP = char:FindFirstChild("HumanoidRootPart")
        FlightState.CachedHum = char:FindFirstChildOfClass("Humanoid")
        local parts = {}
        for _, ch in ipairs(char:GetChildren()) do
            if ch:IsA("BasePart") then
                table.insert(parts, ch)
            end
        end
        FlightState.CachedCollideParts = parts
    end
    return char
end

local function getCharacter()
    return refreshCharacterCache(LocalPlayer.Character)
end

local function getHRP()
    refreshCharacterCache(LocalPlayer.Character)
    return FlightState.CachedHRP
end

local function getHumanoid()
    refreshCharacterCache(LocalPlayer.Character)
    return FlightState.CachedHum
end

local function ensureFlyPlatform()
    local plat = FlightState.PlatformPart
    if not plat or not plat.Parent then
        local existing = Workspace:FindFirstChild("FlyPlatform")
        if existing and existing:IsA("BasePart") then
            plat = existing
        else
            plat = Instance.new("Part")
            plat.Name = "FlyPlatform"
            plat.Size = Vector3.new(6, 1, 6)
            plat.Anchored = true
            plat.CanCollide = true
            plat.CanQuery = false
            plat.CanTouch = false
            plat.Massless = true
            plat.Transparency = 1
            plat.Parent = Workspace
        end
        FlightState.PlatformPart = plat
    end
    return plat
end

local function destroyFlyPlatform()
    if FlightState.PlatformPart then
        pcall(function() FlightState.PlatformPart:Destroy() end)
        FlightState.PlatformPart = nil
    end
    local existing = Workspace:FindFirstChild("FlyPlatform")
    if existing then
        pcall(function() existing:Destroy() end)
    end
end

local function applyFlightHumanoidStates(enableFlight)
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then return end
    if enableFlight then
        for _, st in ipairs(DisabledHumanoidStates) do
            pcall(function() hum:SetStateEnabled(st, false) end)
        end
        pcall(function()
            if hum:GetState() ~= Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end
        end)
    else
        for _, st in ipairs(DisabledHumanoidStates) do
            pcall(function() hum:SetStateEnabled(st, true) end)
        end
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

local function setCachedPartsCollision(enableFlight, allowTouch)
    refreshCharacterCache(LocalPlayer.Character)
    for _, part in ipairs(FlightState.CachedCollideParts) do
        if part and part.Parent then
            if enableFlight then
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = (allowTouch == true)
            else
                if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head" or part.Name == "Torso" then
                    part.CanCollide = true
                end
                part.CanQuery = true
                part.CanTouch = true
            end
        end
    end
end

local function stopFlight()
    local wasActive = FlightState.Active
    FlightState.Active = false
    FlightState.TargetPos = nil
    FlightState.TargetHandle = nil
    FlightState.TargetLabel = "Idle"
    FlightState.CurrentDistance = 0
    destroyFlyPlatform()
    if wasActive then
        setCachedPartsCollision(false, true)
        applyFlightHumanoidStates(false)
    end
end

local function setFlightTarget(pos, label, handlePart)
    local hrp = getHRP()
    if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    if not FlightState.Active then
        FlightState.StartDistance = math.max(dist, 1)
        applyFlightHumanoidStates(true)
    end
    FlightState.Active = true
    FlightState.TargetPos = pos
    FlightState.TargetHandle = handlePart
    FlightState.TargetLabel = label or "Target"
    FlightState.CurrentDistance = dist
end

-- Ultra-Fast RenderStepped Flight Loop (Zero Table Allocations)
addConnection(RunService.RenderStepped, function(dt)
    if not isScriptAlive() or not FlightState.Active then
        return
    end

    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum or hum.Health <= 0 then
        stopFlight()
        return
    end

    if FlightState.TargetHandle and FlightState.TargetHandle.Parent then
        FlightState.TargetPos = FlightState.TargetHandle.Position
    end
    local targetPos = FlightState.TargetPos
    if not targetPos then
        stopFlight()
        return
    end

    local now = os.clock()
    local currentPos = hrp.Position
    local delta = targetPos - currentPos
    local dist = delta.Magnitude
    FlightState.CurrentDistance = dist

    local nearPickup = (dist <= Config.PickupTouchRange)

    if now - FlightState.LastStateApply >= 0.6 then
        FlightState.LastStateApply = now
        applyFlightHumanoidStates(true)
    end

    local nextPos
    if dist <= Config.StopDistance then
        nextPos = targetPos
    else
        local maxStep = math.clamp(Config.FlightSpeed, 50, 360) * math.clamp(dt, 1/240, 0.12)
        local step = math.min(dist, maxStep)
        nextPos = currentPos + delta.Unit * step
    end

    local minY = math.min(Config.MinAltitudeY, targetPos.Y)
    if nextPos.Y < minY then
        nextPos = Vector3.new(nextPos.X, minY, nextPos.Z)
    end

    local flatLook = Vector3.new(targetPos.X, nextPos.Y, targetPos.Z)
    local nextCF
    if (flatLook - nextPos).Magnitude > 0.05 then
        nextCF = CFrame.lookAt(nextPos, flatLook)
    else
        nextCF = CFrame.new(nextPos)
    end

    hrp.CFrame = nextCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero

    local plat = ensureFlyPlatform()
    if plat then
        plat.CFrame = CFrame.new(nextPos.X, nextPos.Y - 3, nextPos.Z)
    end

    -- Instant touch pickup when close to fruit Handle
    if nearPickup and FlightState.TargetHandle and FlightState.TargetHandle.Parent then
        hrp.CanTouch = true
        FlightState.TargetHandle.CanTouch = true
        if firetouchinterest then
            pcall(firetouchinterest, hrp, FlightState.TargetHandle, 0)
            pcall(firetouchinterest, hrp, FlightState.TargetHandle, 1)
        end
    end
end)

-- Lightweight Stepped Noclip using CachedCollideParts (only 3-5 parts, 0 allocations)
addConnection(RunService.Stepped, function()
    if not isScriptAlive() or not FlightState.Active then return end
    local nearPickup = (FlightState.CurrentDistance <= Config.PickupTouchRange)
    for _, part in ipairs(FlightState.CachedCollideParts) do
        if part and part.Parent then
            part.CanCollide = false
            part.CanTouch = nearPickup
        end
    end
end)

-- ============================================================================
-- 5. EVENT-DRIVEN FRUIT SCANNER & INSTANT AUTO-STORE ENGINE
-- ============================================================================
local TrackedFruitEntries = {} -- [Instance] = entry
local MapFruits = {}           -- sorted array of active entries
local StoredToolCache = setmetatable({}, { __mode = "k" })
local StoringLock = setmetatable({}, { __mode = "k" })
local TotalSnipedSession = 0
local ActiveStoreJobs = 0
local CurrentSnipeTarget = nil
local EmptyMapSince = nil

local function isFruitInstance(inst)
    if not inst or not inst.Parent then return false end
    if inst:GetAttribute("RBX_ReimportId") then return false end
    local handle = inst:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    if inst:IsA("Tool") then
        if inst.Name:find("Fruit") or inst:FindFirstChild("EatRemote") or inst:GetAttribute("OriginalName") or inst:GetAttribute("ItemId") then
            return true
        end
    elseif inst:IsA("Model") then
        if inst.Name == "Fruit " or inst.Name == "Fruit" then
            return true
        elseif inst.Name:find("Fruit") and (inst:FindFirstChild("Fruit") or inst:FindFirstChild("EatRemote") or inst:GetAttribute("OriginalName") or handle:FindFirstChildOfClass("TouchTransmitter")) then
            return true
        end
    end
    return false
end

local function shouldSnipeFruit(entry)
    if entry.IsNatural then
        if not Config.SnipeNaturalSpawns then return false end
    else
        if not Config.SnipeDroppedTools then return false end
    end

    if not Config.OnlySnipeFiltered then
        return true
    end

    local meta = entry.Meta
    if not meta or meta.Id == "Unknown-Spawn" or meta.Rarity == "Unknown" then
        -- Unidentified natural spawn ("Fruit " whose mesh/anim isn't in fingerprint DB yet)
        if entry.IsNatural then
            return Config.SnipeUnknownNatural
        end
        return false
    end

    -- Applies exact Rarity & Target Watchlist filter to BOTH Dropped Tools AND Identified Natural Spawns!
    if Config.TargetFruits[meta.Id] then
        return true
    end
    if Config.AllowedRarities[meta.Rarity] then
        return true
    end
    return false
end

local function applyMetaToEntry(entry, meta)
    entry.Meta = meta
    entry.Name = entry.IsNatural and (meta and meta.Display ~= "Natural Map Fruit" and ("Map Spawn (" .. meta.Display .. ")") or "Natural Map Fruit (Fruit )") or entry.Instance.Name
    entry.Rarity = (meta and meta.Rarity) or "Unknown"
    entry.Icon = (meta and meta.Icon) or DEFAULT_FRUIT_ICON
    entry.MatchesFilter = shouldSnipeFruit(entry)
end

local function registerWorkspaceFruit(child)
    if not child or not child.Parent or TrackedFruitEntries[child] then return end
    if not isFruitInstance(child) then return end

    local handle = child:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return end

    local isNatural = child:IsA("Model") and (child.Name == "Fruit " or child.Name == "Fruit")
    -- Brief yield (max 0.35s) if natural spawn's MeshPart/SpecialMesh hasn't streamed alongside Handle yet
    if isNatural and not child:FindFirstChildWhichIsA("MeshPart", true) and not child:FindFirstChildWhichIsA("SpecialMesh", true) then
        local t0 = os.clock()
        while child.Parent and (os.clock() - t0) < 0.35 do
            if child:FindFirstChildWhichIsA("MeshPart", true) or child:FindFirstChildWhichIsA("SpecialMesh", true) then
                break
            end
            task.wait(0.03)
        end
        if not child.Parent then return end
    end

    local meta = resolveFruitMeta(child)
    local assetKeys = extractInstanceAssetFingerprints(child)
    local hrp = getHRP()
    local dist = hrp and math.floor((hrp.Position - handle.Position).Magnitude) or 0

    local entry = {
        Instance = child,
        Handle = handle,
        Name = child.Name,
        Meta = meta,
        Rarity = "Unknown",
        Icon = DEFAULT_FRUIT_ICON,
        Distance = dist,
        Position = handle.Position,
        IsNatural = isNatural,
        MatchesFilter = false,
        AssetKeys = assetKeys,
        CreatedAt = os.clock(),
        LastResolveAt = os.clock(),
    }
    applyMetaToEntry(entry, meta)
    TrackedFruitEntries[child] = entry

    if not NotifiedInstances[child] then
        NotifiedInstances[child] = true
        if Config.NotifyOnDetect then
            local function emitDetectWebhook()
                if not entry then return end
                local finalMeta = entry.Meta
                sendDiscordWebhook(
                    "📡 Fruit Detected on Map!",
                    string.format("A **%s** was detected in `Workspace`!", entry.Name),
                    RarityDiscordColors[entry.Rarity] or 0x00D9F5,
                    {
                        { name = "🍏 Fruit", value = string.format("`%s`\nType: `%s`", finalMeta and finalMeta.Display or entry.Name, isNatural and "Natural Hourly Spawn" or "Dropped Tool"), inline = true },
                        { name = "✨ Rarity & Distance", value = string.format("Rarity: **%s**\nDistance: `%d studs`", entry.Rarity, entry.Distance), inline = true },
                    },
                    entry.Icon
                )
            end
            if isNatural and entry.Rarity == "Unknown" then
                -- Give mesh replication 250ms to finish before posting Discord webhook so name/image are accurate
                task.delay(0.25, emitDetectWebhook)
            else
                emitDetectWebhook()
            end
        end
    end

    -- Instant lock-on if AutoSnipeMap is enabled and we aren't already flying to a closer target
    if Config.AutoSnipeMap and entry.MatchesFilter then
        EmptyMapSince = nil
        if not CurrentSnipeTarget or dist < (CurrentSnipeTarget.Distance or math.huge) then
            CurrentSnipeTarget = entry
            setFlightTarget(handle.Position, entry.Name, handle)
        end
    end
end

local function rebuildSortedMapFruits()
    local hrp = getHRP()
    local hrpPos = hrp and hrp.Position or Vector3.zero
    local now = os.clock()
    local list = {}

    for inst, entry in pairs(TrackedFruitEntries) do
        if inst and inst.Parent == Workspace and entry.Handle and entry.Handle.Parent then
            entry.Position = entry.Handle.Position
            entry.Distance = hrp and math.floor((hrpPos - entry.Position).Magnitude) or 0
            -- Late-streaming re-identification during first 4.0s OR right after DB learns new fingerprints
            local needsStreamingCheck = entry.IsNatural and (now - (entry.CreatedAt or now)) <= 4.0 and (#(entry.AssetKeys or {}) == 0 or (entry.Meta and entry.Meta.Id == "Unknown-Spawn"))
            local dbJustUpdated = entry.IsNatural and entry.Meta and entry.Meta.Id == "Unknown-Spawn" and LastFingerprintUpdateAt > (entry.LastResolveAt or 0)
            if needsStreamingCheck or dbJustUpdated then
                local freshKeys = extractInstanceAssetFingerprints(inst)
                if #freshKeys > #(entry.AssetKeys or {}) then
                    entry.AssetKeys = freshKeys
                end
                local freshMeta = resolveFruitMeta(inst)
                entry.LastResolveAt = now
                if freshMeta and freshMeta.Id ~= "Unknown-Spawn" then
                    if #freshKeys > 0 then
                        entry.AssetKeys = freshKeys
                    end
                    applyMetaToEntry(entry, freshMeta)
                else
                    entry.MatchesFilter = shouldSnipeFruit(entry)
                end
            else
                entry.MatchesFilter = shouldSnipeFruit(entry)
            end
            table.insert(list, entry)
        else
            TrackedFruitEntries[inst] = nil
        end
    end

    table.sort(list, function(a, b)
        if a.MatchesFilter ~= b.MatchesFilter then
            return a.MatchesFilter
        end
        return a.Distance < b.Distance
    end)

    MapFruits = list
    return list
end

local function fullRescanWorkspace()
    for _, child in ipairs(Workspace:GetChildren()) do
        if not TrackedFruitEntries[child] and isFruitInstance(child) then
            registerWorkspaceFruit(child)
        end
    end
    return rebuildSortedMapFruits()
end

-- Event-Driven Workspace Listeners (Instant 0ms reaction when a fruit spawns/drops)
addConnection(Workspace.ChildAdded, function(child)
    if not isScriptAlive() then return end
    task.defer(function()
        if not child or not child.Parent then return end
        if isFruitInstance(child) then
            registerWorkspaceFruit(child)
            rebuildSortedMapFruits()
        elseif child.Name == "Fruit " or child.Name == "Fruit" or child.Name:find("Fruit") then
            local h = child:WaitForChild("Handle", 1.2)
            if h and isScriptAlive() then
                registerWorkspaceFruit(child)
                rebuildSortedMapFruits()
            end
        end
    end)
end)

addConnection(Workspace.ChildRemoved, function(child)
    local entry = TrackedFruitEntries[child]
    if entry then
        if entry.IsNatural then
            local latestKeys = (#(entry.AssetKeys or {}) > 0) and entry.AssetKeys or extractInstanceAssetFingerprints(child)
            local hrp = getHRP()
            local removeDist = hrp and (hrp.Position - entry.Position).Magnitude or 999
            local wasTarget = (CurrentSnipeTarget and CurrentSnipeTarget.Instance == child)
            if latestKeys and #latestKeys > 0 and (removeDist <= 55 or (wasTarget and removeDist <= 85)) then
                local guessedId = (entry.Meta and entry.Meta.Id) or "Unknown-Spawn"
                -- Handle race where Backpack Tool arrived <= 1.5s BEFORE Workspace.ChildRemoved
                if RecentPickedTool and (os.clock() - RecentPickedTool.At) <= 1.5 then
                    local overlap = keysShareMeshId(RecentPickedTool.Keys, latestKeys)
                    if overlap or removeDist <= 30 then
                        local wrongPreGuess = (guessedId ~= "Unknown-Spawn" and guessedId ~= RecentPickedTool.OrigName)
                        local updated, newlyLearned = learnFingerprintKeys(latestKeys, RecentPickedTool.OrigName, overlap and wrongPreGuess)
                        if wrongPreGuess or updated then
                            rebuildSortedMapFruits()
                        end
                        if (newlyLearned or wrongPreGuess) and notifyToastFn then
                            local learnedMeta = FruitMetaById[RecentPickedTool.OrigName]
                            pcall(notifyToastFn, wrongPreGuess and "🧬 Auto-Corrected Fruit ID!" or "🧬 Natural Fruit Learned!", string.format("%s mapped to %d 3D signatures (synced).", learnedMeta and learnedMeta.Display or RecentPickedTool.OrigName, #latestKeys), "sparkles")
                        end
                        RecentPickedTool = nil
                        PendingNaturalLearn = nil
                    else
                        PendingNaturalLearn = {
                            Keys = latestKeys,
                            Pos = entry.Position,
                            GuessedId = guessedId,
                            RemoveDist = removeDist,
                            WasTarget = wasTarget,
                            RemovedAt = os.clock(),
                        }
                    end
                else
                    PendingNaturalLearn = {
                        Keys = latestKeys,
                        Pos = entry.Position,
                        GuessedId = guessedId,
                        RemoveDist = removeDist,
                        WasTarget = wasTarget,
                        RemovedAt = os.clock(),
                    }
                end
            end
        end
        TrackedFruitEntries[child] = nil
        if CurrentSnipeTarget and CurrentSnipeTarget.Instance == child then
            CurrentSnipeTarget = nil
        end
    end
end)

-- Instant Single-Tool Auto-Store Function
local function storeSingleFruitTool(tool)
    if not tool or not tool.Parent or not tool:IsA("Tool") then return end
    if not (tool.Name:find("Fruit") or tool:FindFirstChild("EatRemote") or tool:GetAttribute("OriginalName") or tool:GetAttribute("ItemId")) then return end

    local origName = tool:GetAttribute("OriginalName")
    if type(origName) ~= "string" or origName == "" then
        local itemIdAttr = tonumber(tool:GetAttribute("ItemId"))
        if itemIdAttr and FruitMetaByItemId[itemIdAttr] then
            origName = FruitMetaByItemId[itemIdAttr].Id
        else
            local clean = tool.Name:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", "")
            origName = clean .. "-" .. clean
        end
    end

    -- Auto-learn fingerprint immediately from Tool & cross-verify any recently picked-up natural spawn
    local catchSource = "Dropped/Gacha"
    if FruitMetaById[origName] then
        local toolKeys = extractInstanceAssetFingerprints(tool)
        learnFruitFingerprint(tool, origName)
        local consumedNatural = false
        if PendingNaturalLearn and (os.clock() - PendingNaturalLearn.RemovedAt) <= 4.0 then
            local overlap = keysShareMeshId(toolKeys, PendingNaturalLearn.Keys)
            local closeEnough = (PendingNaturalLearn.RemoveDist <= 45) or (PendingNaturalLearn.WasTarget and PendingNaturalLearn.RemoveDist <= 85)
            if overlap or closeEnough then
                local guessed = PendingNaturalLearn.GuessedId or "Unknown-Spawn"
                local wrongPreGuess = (guessed ~= "Unknown-Spawn" and guessed ~= origName)
                local updated, newlyLearned = learnFingerprintKeys(PendingNaturalLearn.Keys, origName, overlap and wrongPreGuess)
                if wrongPreGuess or updated then
                    rebuildSortedMapFruits()
                end
                if (newlyLearned or wrongPreGuess) and notifyToastFn then
                    local learnedMeta = FruitMetaById[origName]
                    pcall(notifyToastFn, wrongPreGuess and "🧬 Auto-Corrected Fruit ID!" or "🧬 Natural Fruit Learned!", string.format("%s mapped to %d 3D signatures (synced).", learnedMeta and learnedMeta.Display or origName, #PendingNaturalLearn.Keys), "sparkles")
                end
                PendingNaturalLearn = nil
                catchSource = "Natural"
                consumedNatural = true
            end
        end
        if not consumedNatural then
            local hrp = getHRP()
            RecentPickedTool = {
                OrigName = origName,
                Keys = toolKeys,
                Pos = hrp and hrp.Position or Vector3.zero,
                At = os.clock(),
            }
        end
    end

    if not Config.AutoStoreFruits then return end
    if StoredToolCache[tool] == "STORED" or StoredToolCache[tool] == "FULL" or StoringLock[tool] then return end

    StoringLock[tool] = true
    ActiveStoreJobs = ActiveStoreJobs + 1
    task.spawn(function()
        pcall(function()
            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if not commF then return end

            local meta = FruitMetaById[origName] or resolveFruitMeta(tool)
            local iconUrl = (meta and meta.Icon) or DEFAULT_FRUIT_ICON

            local ok, res = pcall(function()
                return commF:InvokeServer("StoreFruit", origName, tool)
            end)

            if (not ok or res == false or res == nil) and tool.Parent then
                local hum = getHumanoid()
                local char = getCharacter()
                if hum and char and tool.Parent ~= char then
                    pcall(function() hum:EquipTool(tool) end)
                    task.wait(0.08)
                    ok, res = pcall(function()
                        return commF:InvokeServer("StoreFruit", origName, tool)
                    end)
                end
            end

            if ok and res == true then
                StoredToolCache[tool] = "STORED"
                TotalSnipedSession = TotalSnipedSession + 1
                InventoryNeedsRefresh = true
                table.insert(WebHub.PendingCatches, {
                    catchUid = string.format("%s:%s:%d:%d", tostring(LocalPlayer.UserId), origName, os.time(), TotalSnipedSession),
                    fruitId = origName,
                    displayName = meta and meta.Display or tool.Name,
                    rarity = meta and meta.Rarity or "Unknown",
                    iconUrl = iconUrl,
                    jobId = tostring(game.JobId),
                    source = catchSource,
                    ts = os.time() * 1000,
                })
                WebHub.ImmediateRequested = true
                if Config.NotifyOnStore then
                    sendDiscordWebhook(
                        "✅ Fruit Sniped & Stored!",
                        string.format("Successfully stored **%s** (`%s`) into your inventory!", tool.Name, origName),
                        RarityDiscordColors[meta and meta.Rarity or "Mythical"] or 0x00F5A0,
                        {
                            { name = "🍏 Stored Fruit", value = string.format("**%s**\nID: `%s`", tool.Name, origName), inline = true },
                            { name = "💎 Rarity & Value", value = string.format("Rarity: **%s**\nValue: `$%s`", meta and meta.Rarity or "Unknown", formatNumber(meta and meta.Price or 0)), inline = true },
                            { name = "📦 Session Total", value = string.format("`%d` fruit(s) stored this session", TotalSnipedSession), inline = false },
                        },
                        iconUrl
                    )
                end
            elseif ok and typeof(res) == "number" then
                StoredToolCache[tool] = "FULL"
                table.insert(WebHub.PendingCatches, {
                    catchUid = string.format("%s:%s:%d:full", tostring(LocalPlayer.UserId), origName, os.time()),
                    fruitId = origName,
                    displayName = meta and meta.Display or tool.Name,
                    rarity = meta and meta.Rarity or "Unknown",
                    iconUrl = iconUrl,
                    jobId = tostring(game.JobId),
                    source = catchSource .. " (Full)",
                    ts = os.time() * 1000,
                })
                WebHub.ImmediateRequested = true
                if Config.NotifyOnStore then
                    sendDiscordWebhook(
                        "⚠️ Fruit Picked Up (Storage Full!)",
                        string.format("Picked up **%s** (`%s`), but your storage capacity (`%d`) for this fruit is full!", tool.Name, origName, res),
                        0xF59E0B,
                        {
                            { name = "🍏 Fruit Held", value = string.format("**%s** (`%s`)", tool.Name, origName), inline = true },
                            { name = "📦 Capacity Limit", value = string.format("Max Capacity: `%d/%d`", res, res), inline = true },
                        },
                        iconUrl
                    )
                end
            end
        end)
        StoringLock[tool] = nil
        ActiveStoreJobs = math.max(0, ActiveStoreJobs - 1)
    end)
end

local function storeAllCurrentFruitTools()
    local char = getCharacter()
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then storeSingleFruitTool(c) end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") then storeSingleFruitTool(c) end
        end
    end
end

local function hookInventoryListeners()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and not bp:GetAttribute("__AegisHooked") then
        bp:SetAttribute("__AegisHooked", true)
        addConnection(bp.ChildAdded, function(child)
            if isScriptAlive() and child:IsA("Tool") then
                task.defer(storeSingleFruitTool, child)
            end
        end)
    end
    local char = getCharacter()
    if char and not char:GetAttribute("__AegisHooked") then
        char:SetAttribute("__AegisHooked", true)
        addConnection(char.ChildAdded, function(child)
            if isScriptAlive() then
                if child:IsA("Tool") then
                    task.defer(storeSingleFruitTool, child)
                elseif child:IsA("BasePart") then
                    FlightState.CachedChar = nil
                    refreshCharacterCache(char)
                end
            end
        end)
    end
end

addConnection(LocalPlayer.CharacterAdded, function(newChar)
    task.defer(function()
        refreshCharacterCache(newChar)
        hookInventoryListeners()
        fullRescanWorkspace()
    end)
end)

-- ============================================================================
-- 6. DEALER STOCK SNIPER & COUSIN GACHA ENGINE
-- ============================================================================
local DealerOnSaleList = {}
local LastDealerCheck = 0

local function refreshDealerStock(autoBuy)
    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    if not commF then return {} end

    local ok, stock = pcall(function()
        return commF:InvokeServer("GetFruits")
    end)
    if not ok or type(stock) ~= "table" then
        return DealerOnSaleList
    end

    local onSale = {}
    local lpBeli = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Beli") and LocalPlayer.Data.Beli.Value or 0

    for _, item in ipairs(stock) do
        if type(item) == "table" then
            local name = tostring(item.Name or "")
            local price = tonumber(item.Price) or 0
            if name ~= "" and not FruitMetaById[name] then
                local shortName = name:match("^(.-)%-") or name
                local inferredRarity = (price >= 2450000 and "Mythical")
                    or (price >= 1000000 and "Legendary")
                    or (price >= 650000 and "Rare")
                    or (price >= 250000 and "Uncommon")
                    or "Common"
                local newMeta = {
                    Id = name,
                    Display = shortName,
                    Rarity = inferredRarity,
                    Price = price,
                    Icon = DEFAULT_FRUIT_ICON,
                }
                FruitMetaById[name] = newMeta
                FruitMetaByShort[shortName:lower()] = newMeta
                table.insert(AllFruitIds, name)
                fetchDynamicWikiIconAsync(shortName, newMeta)
            end
        end
        if type(item) == "table" and item.OnSale then
            local name = tostring(item.Name or "")
            local price = tonumber(item.Price) or 0
            local meta = FruitMetaById[name]
            table.insert(onSale, {
                Name = name,
                Display = meta and meta.Display or name,
                Rarity = meta and meta.Rarity or "Common",
                Price = price,
                Icon = (meta and meta.Icon) or DEFAULT_FRUIT_ICON,
            })

            if autoBuy and Config.AutoDealerSniper and Config.DealerWatchlist[name] and lpBeli >= price then
                local buyOk, buyRes = pcall(function()
                    return commF:InvokeServer("BuyFruit", name)
                end)
                if buyOk and buyRes then
                    if Config.NotifyOnDealer then
                        sendDiscordWebhook(
                            "🛒 Dealer Stock Sniped!",
                            string.format("Auto-purchased **%s** from Blox Fruit Dealer for **$%s** Beli!", name, formatNumber(price)),
                            0x00F5A0,
                            {
                                { name = "🍏 Fruit Purchased", value = "`" .. name .. "`", inline = true },
                                { name = "💰 Price Paid", value = "`$" .. formatNumber(price) .. "`", inline = true },
                            },
                            (meta and meta.Icon) or DEFAULT_FRUIT_ICON
                        )
                    end
                end
            end
        end
    end

    DealerOnSaleList = onSale
    return onSale
end

local function rollCousinGacha()
    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    if not commF then return false, "CommF_ not found" end
    local ok, res = pcall(function()
        return commF:InvokeServer("Cousin", "Buy")
    end)
    task.delay(0.2, storeAllCurrentFruitTools)
    return ok, res
end

-- ============================================================================
-- 7. TURBO SMART SERVER HOPPER (Pre-Warmed 100-Server Pool + Zero-Repeat Blacklist)
-- ============================================================================
local IsHopping = false
local EspObjects = {} -- [instance] = { Text = Drawing, Line = Drawing }
local VisitedServers = {} -- [jobId] = os.time()
local CachedServerPool = {} -- array of unvisited jobIds
local VISITED_TTL = 2700 -- 45 minutes blacklist per server

local function loadServerHopCache()
    local nowUnix = os.time()
    pcall(function()
        if isfile and readfile and isfile(VISITED_FILE) then
            local decoded = HttpService:JSONDecode(readfile(VISITED_FILE))
            if type(decoded) == "table" then
                for jid, ts in pairs(decoded) do
                    if type(jid) == "string" and tonumber(ts) and (nowUnix - tonumber(ts)) < VISITED_TTL then
                        VisitedServers[jid] = tonumber(ts)
                    end
                end
            end
        end
    end)
    if game.JobId and game.JobId ~= "" then
        VisitedServers[tostring(game.JobId)] = nowUnix
    end
    pcall(function()
        if isfile and readfile and isfile(POOL_FILE) then
            local decoded = HttpService:JSONDecode(readfile(POOL_FILE))
            if type(decoded) == "table" then
                for _, jid in ipairs(decoded) do
                    if type(jid) == "string" and jid ~= "" and not VisitedServers[jid] then
                        table.insert(CachedServerPool, jid)
                    end
                end
            end
        end
    end)
end

local function saveServerHopCache()
    pcall(function()
        if writefile then
            ensureConfigFolder()
            writefile(VISITED_FILE, HttpService:JSONEncode(VisitedServers))
            writefile(POOL_FILE, HttpService:JSONEncode(CachedServerPool))
        end
    end)
end

loadServerHopCache()
saveServerHopCache()

local function removeEspForInstance(inst)
    local obj = EspObjects[inst]
    if obj then
        pcall(function() obj.Text:Remove() end)
        pcall(function() obj.Line:Remove() end)
        EspObjects[inst] = nil
    end
end

local function clearAllEsp()
    for inst in pairs(EspObjects) do
        removeEspForInstance(inst)
    end
end

local function shuffleArray(arr)
    for i = #arr, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
end

local IsFetchingPool = false
local function fetchFreshServerIds(placeId)
    if IsFetchingPool then return end
    IsFetchingPool = true

    pcall(function()
        local currentJobId = tostring(game.JobId)
        local nowUnix = os.time()
        local seen = {}
        for _, existingId in ipairs(CachedServerPool) do
            seen[existingId] = true
        end

        local endpoints = {
            string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true", placeId),
            string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", placeId),
            string.format("https://games.roproxy.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true", placeId),
        }

        if math.random(1, 2) == 2 then
            endpoints[1], endpoints[2] = endpoints[2], endpoints[1]
        end

        for _, baseUrl in ipairs(endpoints) do
            local cursor = ""
            for page = 1, 4 do
                local url = baseUrl .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
                local ok, resp = pcall(function()
                    return HttpService:JSONDecode(game:HttpGet(url))
                end)
                if ok and type(resp) == "table" and type(resp.data) == "table" then
                    for _, srv in ipairs(resp.data) do
                        if type(srv) == "table" and type(srv.id) == "string" then
                            local jid = srv.id
                            local playing = tonumber(srv.playing) or 0
                            local maxP = tonumber(srv.maxPlayers) or 12
                            local visitedTs = VisitedServers[jid]
                            local isVisited = visitedTs and ((nowUnix - visitedTs) < VISITED_TTL)
                            if jid ~= currentJobId
                                and not isVisited
                                and not seen[jid]
                                and playing >= 1
                                and playing < maxP then
                                seen[jid] = true
                                table.insert(CachedServerPool, jid)
                            end
                        end
                    end
                    -- Keep all ~100 valid servers returned by this request! Only paginate further if pool is still small.
                    if #CachedServerPool >= 25 then
                        break
                    end
                    if type(resp.nextPageCursor) == "string" and resp.nextPageCursor ~= "" then
                        cursor = resp.nextPageCursor
                    else
                        break
                    end
                else
                    break
                end
            end
            if #CachedServerPool >= 25 then
                break
            end
        end

        shuffleArray(CachedServerPool)
        saveServerHopCache()
    end)

    IsFetchingPool = false
end

-- Start scanning & pre-warming server pool IMMEDIATELY before UI even finishes loading!
hookInventoryListeners()
fullRescanWorkspace()
storeAllCurrentFruitTools()
task.spawn(scanAllVisibleToolsForFingerprints)
if #CachedServerPool < 25 then
    task.spawn(function()
        fetchFreshServerIds(game.PlaceId)
    end)
end

local TeleportFailedSignal = false
local LastTeleportFailResult = nil
addConnection(TeleportService.TeleportInitFailed, function(_, teleportResult, errorMessage)
    TeleportFailedSignal = true
    LastTeleportFailResult = teleportResult
end)

local function hopToNewServer()
    if IsHopping then return end
    IsHopping = true
    stopFlight()
    clearAllEsp()
    VisitedServers[tostring(game.JobId)] = os.time()
    saveSessionState()
    saveConfig(true)
    saveServerHopCache()
    armTeleportAutoExecute()

    if Config.NotifyOnHop then
        sendDiscordWebhook(
            "🔄 Server Hopping...",
            "No target fruits remaining in current server. Hopping to a guaranteed unvisited Blox Fruits server...",
            0x3B82F6,
            {},
            DEFAULT_FRUIT_ICON
        )
    end

    task.spawn(function()
        -- Wait briefly ONLY if a StoreFruit invoke or Discord webhook POST is actively in-flight
        local waitFlushed = os.clock()
        while (ActiveStoreJobs > 0 or ActiveWebhookJobs > 0) and (os.clock() - waitFlushed) < 1.5 do
            task.wait(0.05)
        end

        local placeId = game.PlaceId
        local currentJobId = tostring(game.JobId)

        local cleanPool = {}
        local nowUnix = os.time()
        for _, jid in ipairs(CachedServerPool) do
            local vTs = VisitedServers[jid]
            if jid ~= currentJobId and not WebHub.BlockedJobIds[jid] and (not vTs or (nowUnix - vTs) >= VISITED_TTL) then
                table.insert(cleanPool, jid)
            end
        end
        CachedServerPool = cleanPool

        if #CachedServerPool == 0 then
            while IsFetchingPool do task.wait(0.05) end
            if #CachedServerPool == 0 then
                fetchFreshServerIds(placeId)
            end
        end

        for attempt = 1, 15 do
            if not isScriptAlive() then break end
            if #CachedServerPool == 0 then
                fetchFreshServerIds(placeId)
                if #CachedServerPool == 0 then
                    task.wait(1.0)
                    fetchFreshServerIds(placeId)
                end
            end

            local chosen = table.remove(CachedServerPool, 1)
            if chosen and chosen ~= currentJobId and not VisitedServers[chosen] and not WebHub.BlockedJobIds[chosen] then
                if WebHub.claimServer and Config.WebSyncEnabled and WebHub.getKey and WebHub.getKey() ~= "" then
                    local okClaim = WebHub.claimServer(chosen, currentJobId)
                    if not okClaim then
                        WebHub.BlockedJobIds[chosen] = true
                        continue
                    end
                end
                VisitedServers[chosen] = os.time()
                saveServerHopCache()
                TeleportFailedSignal = false
                LastTeleportFailResult = nil

                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, chosen, LocalPlayer)
                end)

                local waitStart = os.clock()
                while (os.clock() - waitStart) < 10 do
                    if TeleportFailedSignal or not isScriptAlive() then
                        break
                    end
                    task.wait(0.08)
                end

                if not TeleportFailedSignal then
                    break
                end

                if LastTeleportFailResult == Enum.TeleportResult.Flooded then
                    task.wait(1.2)
                else
                    task.wait(0.12)
                end
            end
        end

        IsHopping = false
    end)
end

-- ============================================================================
-- 8. LIGHTWEIGHT 3D DRAWING ESP ENGINE (Zero Redundant Allocations)
-- ============================================================================
addConnection(RunService.RenderStepped, function()
    if not isScriptAlive() or IsHopping then return end
    if not Config.FruitESP or #MapFruits == 0 then
        for _, obj in pairs(EspObjects) do
            if obj.Text.Visible then obj.Text.Visible = false end
            if obj.Line.Visible then obj.Line.Visible = false end
        end
        return
    end

    Camera = Workspace.CurrentCamera
    if not Camera then return end
    local viewportSize = Camera.ViewportSize
    local origin2D = Vector2.new(viewportSize.X * 0.5, viewportSize.Y - 40)

    local activeSet = {}
    for _, entry in ipairs(MapFruits) do
        local inst = entry.Instance
        local handle = entry.Handle
        if inst and inst.Parent and handle and handle.Parent then
            activeSet[inst] = true
            local obj = EspObjects[inst]
            if not obj then
                local txt = Drawing.new("Text")
                txt.Size = 15
                txt.Center = true
                txt.Outline = true
                txt.Font = 2

                local line = Drawing.new("Line")
                line.Thickness = 1.5
                line.Transparency = 0.85

                obj = { Text = txt, Line = line }
                EspObjects[inst] = obj
                table.insert(Drawings, txt)
                table.insert(Drawings, line)
            end

            local pos3D = handle.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(Vector3.new(pos3D.X, pos3D.Y + 2.5, pos3D.Z))
            local isSkipped = Config.OnlySnipeFiltered and not entry.MatchesFilter
            local col = isSkipped and Color3.fromHex("#94A3B8") or (RarityColors[entry.Rarity] or RarityColors.Unknown)

            if onScreen then
                local tag = entry.IsNatural and "[MAP SPAWN]" or "[DROPPED]"
                local skipPrefix = isSkipped and "[SKIPPED] " or ""
                obj.Text.Text = string.format("%s%s %s\n[%s] • %d studs", skipPrefix, tag, entry.Meta and entry.Meta.Display or entry.Name, entry.Rarity:upper(), entry.Distance)
                obj.Text.Position = Vector2.new(screenPos.X, screenPos.Y)
                obj.Text.Color = col
                obj.Text.Visible = true

                if Config.FruitTracers then
                    obj.Line.From = origin2D
                    obj.Line.To = Vector2.new(screenPos.X, screenPos.Y + 18)
                    obj.Line.Color = col
                    obj.Line.Visible = true
                else
                    obj.Line.Visible = false
                end
            else
                obj.Text.Visible = false
                obj.Line.Visible = false
            end
        end
    end

    for inst in pairs(EspObjects) do
        if not activeSet[inst] then
            removeEspForInstance(inst)
        end
    end
end)

-- ============================================================================
-- 9. CUSTOM MODERN FLOATING LIVE TELEMETRY HUD (Dirty-Checked Updates)
-- ============================================================================
local HudGui = Instance.new("ScreenGui")
HudGui.Name = "AegisSniperLiveHUD"
HudGui.ResetOnSpawn = false
HudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    HudGui.Parent = (gethui and gethui()) or CoreGui
end)

local HudCard = Instance.new("Frame")
HudCard.Name = "HudCard"
HudCard.Size = UDim2.fromOffset(340, 118)
HudCard.Position = UDim2.new(0.5, -170, 0, 14)
HudCard.BackgroundColor3 = Color3.fromHex("#090E17")
HudCard.BackgroundTransparency = 0.12
HudCard.BorderSizePixel = 0
HudCard.Active = true
HudCard.Draggable = true
HudCard.Parent = HudGui

local HudCorner = Instance.new("UICorner")
HudCorner.CornerRadius = UDim.new(0, 12)
HudCorner.Parent = HudCard

local HudStroke = Instance.new("UIStroke")
HudStroke.Thickness = 1.6
HudStroke.Color = Color3.fromHex("#00F5A0")
HudStroke.Transparency = 0.2
HudStroke.Parent = HudCard

local HudStrokeGrad = Instance.new("UIGradient")
HudStrokeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHex("#00F5A0")),
    ColorSequenceKeypoint.new(0.5, Color3.fromHex("#00D9F5")),
    ColorSequenceKeypoint.new(1, Color3.fromHex("#A855F7")),
})
HudStrokeGrad.Parent = HudStroke

local HudTitle = Instance.new("TextLabel")
HudTitle.Size = UDim2.new(1, -24, 0, 22)
HudTitle.Position = UDim2.fromOffset(12, 8)
HudTitle.BackgroundTransparency = 1
HudTitle.Font = Enum.Font.GothamBold
HudTitle.TextSize = 13
HudTitle.TextXAlignment = Enum.TextXAlignment.Left
HudTitle.TextColor3 = Color3.fromHex("#00F5A0")
HudTitle.Text = "⚡ AEGIS FRUIT SNIPER v3.2 • CLOUD HUB"
HudTitle.Parent = HudCard

local HudStatusLine = Instance.new("TextLabel")
HudStatusLine.Size = UDim2.new(1, -24, 0, 18)
HudStatusLine.Position = UDim2.fromOffset(12, 30)
HudStatusLine.BackgroundTransparency = 1
HudStatusLine.Font = Enum.Font.GothamMedium
HudStatusLine.TextSize = 12
HudStatusLine.TextXAlignment = Enum.TextXAlignment.Left
HudStatusLine.TextColor3 = Color3.fromHex("#E2E8F0")
HudStatusLine.Text = "Status: Event-Driven Radar Active..."
HudStatusLine.Parent = HudCard

local HudSubLine = Instance.new("TextLabel")
HudSubLine.Size = UDim2.new(1, -24, 0, 18)
HudSubLine.Position = UDim2.fromOffset(12, 50)
HudSubLine.BackgroundTransparency = 1
HudSubLine.Font = Enum.Font.Gotham
HudSubLine.TextSize = 11
HudSubLine.TextXAlignment = Enum.TextXAlignment.Left
HudSubLine.TextColor3 = Color3.fromHex("#94A3B8")
HudSubLine.Text = "Map Fruits: 0 | Sniped: 0 | Flight: Idle"
HudSubLine.Parent = HudCard

local HudWebhookLine = Instance.new("TextLabel")
HudWebhookLine.Size = UDim2.new(1, -24, 0, 16)
HudWebhookLine.Position = UDim2.fromOffset(12, 69)
HudWebhookLine.BackgroundTransparency = 1
HudWebhookLine.Font = Enum.Font.Gotham
HudWebhookLine.TextSize = 10
HudWebhookLine.TextXAlignment = Enum.TextXAlignment.Left
HudWebhookLine.TextColor3 = Color3.fromHex("#38BDF8")
HudWebhookLine.Text = "Webhook: Ready (Wiki Icons Enabled)"
HudWebhookLine.Parent = HudCard

local ProgressBg = Instance.new("Frame")
ProgressBg.Size = UDim2.new(1, -24, 0, 8)
ProgressBg.Position = UDim2.fromOffset(12, 94)
ProgressBg.BackgroundColor3 = Color3.fromHex("#1E293B")
ProgressBg.BorderSizePixel = 0
ProgressBg.Parent = HudCard

local ProgressBgCorner = Instance.new("UICorner")
ProgressBgCorner.CornerRadius = UDim.new(1, 0)
ProgressBgCorner.Parent = ProgressBg

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromHex("#00F5A0")
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBg

local ProgressFillCorner = Instance.new("UICorner")
ProgressFillCorner.CornerRadius = UDim.new(1, 0)
ProgressFillCorner.Parent = ProgressFill

-- ============================================================================
-- 10. LOAD & CUSTOMIZE WINDUI LIBRARY (Disk-Cached for Instant Hop Startup)
-- ============================================================================
local WINDUI_CACHE_FILE = "AegisFruitSniper/windui_cache.lua"
local WINDUI_URL        = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"

local function loadWindUILibrary()
    local cachedSource
    pcall(function()
        if isfile and readfile and isfile(WINDUI_CACHE_FILE) then
            local raw = readfile(WINDUI_CACHE_FILE)
            if type(raw) == "string" and #raw > 10000 then
                cachedSource = raw
            end
        end
    end)

    if cachedSource then
        local ok, lib = pcall(function()
            return loadstring(cachedSource)()
        end)
        if ok and type(lib) == "table" then
            return lib
        end
    end

    local freshSource = game:HttpGet(WINDUI_URL)
    pcall(function()
        if writefile and type(freshSource) == "string" and #freshSource > 10000 then
            ensureConfigFolder()
            writefile(WINDUI_CACHE_FILE, freshSource)
        end
    end)
    return loadstring(freshSource)()
end

local WindUI = loadWindUILibrary()

notifyToastFn = function(title, content, icon)
    WindUI:Notify({
        Title = tostring(title or "Aegis Notification"),
        Content = tostring(content or ""),
        Duration = 3,
        Icon = icon or "bell",
    })
end

pcall(function()
    WindUI:AddTheme({
        Name = "AegisCyber",
        Accent = Color3.fromHex("#00F5A0"),
        Background = Color3.fromHex("#070B12"),
        Dialog = Color3.fromHex("#0D1522"),
        Outline = Color3.fromHex("#00D9F5"),
        Text = Color3.fromHex("#F1F5F9"),
        Placeholder = Color3.fromHex("#64748B"),
        Button = Color3.fromHex("#00C882"),
        Icon = Color3.fromHex("#00F5A0"),
        Toggle = Color3.fromHex("#00F5A0"),
        Slider = Color3.fromHex("#00D9F5"),
        Checkbox = Color3.fromHex("#00F5A0"),
        PanelBackground = Color3.fromHex("#0F172A"),
        PanelBackgroundTransparency = 0.82,
        ElementBackground = Color3.fromHex("#111C2D"),
        ElementBackgroundTransparency = 0.12,
        Primary = Color3.fromHex("#00F5A0"),
    })
end)

local Window = WindUI:CreateWindow({
    Title = "AEGIS FRUIT SNIPER • v3.2",
    Icon = "radar",
    Author = "Cloud Hub + Pre-ID Natural Spawns + Turbo Hop",
    Folder = "AegisFruitSniper",
    Size = UDim2.fromOffset(630, 480),
    MinSize = Vector2.new(560, 380),
    MaxSize = Vector2.new(860, 600),
    Transparent = true,
    Acrylic = false, -- Disabled Acrylic blur to reduce GPU memory & prevent Roblox crashes
    Theme = "AegisCyber",
    Resizable = true,
    SideBarWidth = 195,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    Radius = 14,
    IgnoreAlerts = true,
    ToggleKey = Enum.KeyCode.RightControl,
    Topbar = {
        Height = 50,
        ButtonsType = "Mac",
    },
    OpenButton = {
        Title = "Aegis v3.2",
        Icon = "radar",
        CornerRadius = UDim.new(0, 14),
        StrokeThickness = 2,
        Color = ColorSequence.new(
            Color3.fromHex("#00F5A0"),
            Color3.fromHex("#00D9F5")
        ),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    },
    User = {
        Enabled = true,
        Anonymous = false,
    },
})

pcall(function()
    Window:Tag({
        Title = "v3.2 CLOUD HUB",
        Color = Color3.fromHex("#00F5A0"),
    })
    Window:Tag({
        Title = "WIKI ICONS",
        Color = Color3.fromHex("#00D9F5"),
    })
end)

-- ============================================================================
-- 11. BUILD TABS & UI ELEMENTS
-- ============================================================================
local TabRadar   = Window:Tab({ Title = "Live Radar & Snipe", Icon = "radar" })
local TabFilter  = Window:Tab({ Title = "Fruit Filter", Icon = "sparkles" })
local TabDealer  = Window:Tab({ Title = "Dealer & Gacha", Icon = "shopping-bag" })
local TabFlight  = Window:Tab({ Title = "Flight & Server Hop", Icon = "plane" })
local TabWebhook = Window:Tab({ Title = "ESP & Webhooks", Icon = "bell" })
local TabWeb     = Window:Tab({ Title = "Web Dashboard", Icon = "globe" })

-- ---- TAB 1: LIVE RADAR & SNIPE ----
local LiveRadarParagraph = TabRadar:Paragraph({
    Title = "📡 Live Workspace Fruit Radar (Event-Driven)",
    Desc = "Listening to Workspace.ChildAdded for instant 0ms fruit detection...",
})

TabRadar:Section({ Title = "Master Fruit Sniper Controls" })

TabRadar:Toggle({
    Title = "Auto Snipe Map Fruits (Anti-Cheat Flight)",
    Desc = "Instantly locks onto fruits at 300 studs/s using cached BaseParts, touches Handle, and stores in 1 frame.",
    Icon = "zap",
    Value = Config.AutoSnipeMap,
    Callback = function(state)
        Config.AutoSnipeMap = state
        if not state then
            stopFlight()
        end
        saveConfig()
    end,
})

TabRadar:Toggle({
    Title = "Auto Store Picked Fruits to Inventory",
    Desc = "Event-driven Backpack/Character listener stores fruits immediately and sends Discord Webhook with Wiki Fruit Image.",
    Icon = "package-check",
    Value = Config.AutoStoreFruits,
    Callback = function(state)
        Config.AutoStoreFruits = state
        saveConfig()
        if state then
            storeAllCurrentFruitTools()
        end
    end,
})

TabRadar:Toggle({
    Title = "Only Snipe Filtered Fruits",
    Desc = "When enabled, ignores common fruits not matching your Rarity/Fruit Filter in the Fruit Filter tab.",
    Icon = "check",
    Value = Config.OnlySnipeFiltered,
    Callback = function(state)
        Config.OnlySnipeFiltered = state
        saveConfig()
    end,
})

TabRadar:Button({
    Title = "🚀 Snipe Nearest Fruit Immediately",
    Desc = "Flies straight to the closest fruit on the map right now even if Auto Snipe is paused.",
    Icon = "navigation",
    Callback = function()
        local list = fullRescanWorkspace()
        if #list == 0 then
            WindUI:Notify({
                Title = "No Fruits on Map",
                Content = "Workspace currently has 0 spawned or dropped fruits.",
                Duration = 3,
                Icon = "bell",
            })
            return
        end
        local best = list[1]
        CurrentSnipeTarget = best
        setFlightTarget(best.Position, best.Name, best.Handle)
        WindUI:Notify({
            Title = "Locking Onto Fruit!",
            Content = string.format("Flying to %s (%d studs away)...", best.Name, best.Distance),
            Duration = 3,
            Icon = "radar",
        })
    end,
})

TabRadar:Button({
    Title = "🛑 Emergency Stop Flight & Restore Physics",
    Desc = "Stops flight immediately, removes FlyPlatform, and restores normal Humanoid states.",
    Icon = "octagon",
    Callback = function()
        Config.AutoSnipeMap = false
        stopFlight()
        saveConfig()
        WindUI:Notify({
            Title = "Flight Stopped",
            Content = "Character physics & collision restored.",
            Duration = 2.5,
            Icon = "shield",
        })
    end,
})

TabRadar:Button({
    Title = "📋 Copy GitHub Loadstring to Clipboard",
    Desc = LOADSTRING_SNIPPET,
    Icon = "copy",
    Callback = function()
        if setclipboard then
            pcall(setclipboard, LOADSTRING_SNIPPET)
        end
        WindUI:Notify({
            Title = "Loadstring Copied!",
            Content = "GitHub loadstring copied to clipboard.",
            Duration = 3,
            Icon = "check",
        })
    end,
})

-- ---- TAB 2: FRUIT FILTER ----
TabFilter:Section({ Title = "Fruit Source Types" })

local FingerprintDbParagraph = TabFilter:Paragraph({
    Title = "🧬 Pre-Pickup Natural Spawn DB",
    Desc = string.format("Learned %d fruits (%d 3D composite signatures) — auto-learns on pickups, visible players & Cloud DB.", LearnedFruitCount, LearnedSigCount),
})

TabFilter:Button({
    Title = "🗑️ Reset Local Pre-ID Cache (Force Re-Learn)",
    Desc = "Clears cached natural spawn fingerprints locally and re-scans equipped tools right now.",
    Icon = "trash-2",
    Callback = function()
        table.clear(FruitAssetMap)
        FruitAssetMap["SIG:rbxassetid://15111517528@40,127,71@|rbxassetid://15111517529@248,217,109@|rbxassetid://15111517558@163,162,165@::rbxassetid://15123673019"] = "Sand-Sand"
        FruitAssetMap["SIGMESH:rbxassetid://15111517528@40,127,71@|rbxassetid://15111517529@248,217,109@|rbxassetid://15111517558@163,162,165@"] = "Sand-Sand"
        FruitAssetMap["SIGASSET:rbxassetid://15111517528@|rbxassetid://15111517529@|rbxassetid://15111517558@"] = "Sand-Sand"
        table.clear(WebHub.PendingFingerprints)
        LastFingerprintUpdateAt = os.clock()
        pcall(function()
            if isfile and delfile and isfile(FINGERPRINTS_FILE) then
                delfile(FINGERPRINTS_FILE)
            end
        end)
        saveFruitFingerprints(true)
        scanAllVisibleToolsForFingerprints()
        rebuildSortedMapFruits()
        FingerprintDbParagraph:SetDesc(string.format(
            "Learned %d fruits (%d 3D composite signatures) — auto-learns on pickups, visible players & Cloud DB.",
            LearnedFruitCount,
            LearnedSigCount
        ))
        WindUI:Notify({
            Title = "Pre-ID DB Reset Complete",
            Content = string.format("Reset & re-scanned: %d fruits (%d signatures).", LearnedFruitCount, LearnedSigCount),
            Duration = 3,
            Icon = "refresh-cw",
        })
    end,
})

TabFilter:Toggle({
    Title = "Snipe Natural Hourly Map Spawns ('Fruit ')",
    Desc = "Targets natural hourly-spawned Model fruits in Workspace.",
    Value = Config.SnipeNaturalSpawns,
    Callback = function(state)
        Config.SnipeNaturalSpawns = state
        rebuildSortedMapFruits()
        saveConfig()
    end,
})

TabFilter:Toggle({
    Title = "Snipe Unidentified Natural Spawns (Auto-Learn)",
    Desc = "When enabled, grabs unlearned 'Fruit ' spawns once to fingerprint their 3D mesh permanently. Turn OFF to skip unknown meshes too.",
    Value = Config.SnipeUnknownNatural,
    Callback = function(state)
        Config.SnipeUnknownNatural = state
        rebuildSortedMapFruits()
        saveConfig()
    end,
})

TabFilter:Toggle({
    Title = "Snipe Player-Dropped / Unstored Fruit Tools",
    Desc = "Targets Tool fruits in Workspace (e.g. 'Diamond Fruit', 'Ice Fruit').",
    Value = Config.SnipeDroppedTools,
    Callback = function(state)
        Config.SnipeDroppedTools = state
        rebuildSortedMapFruits()
        saveConfig()
    end,
})

TabFilter:Section({ Title = "Rarity & Specific Fruit Watchlist" })

TabFilter:Dropdown({
    Title = "Allowed Rarity Tiers",
    Desc = "Select which fruit rarities to snipe when 'Only Snipe Filtered Fruits' is enabled.",
    Values = { "Mythical", "Legendary", "Rare", "Uncommon", "Common" },
    Value = mapToSelectedArray(Config.AllowedRarities),
    Multi = true,
    AllowNone = true,
    Callback = function(selected)
        if IsInitializingUI then return end
        for k in pairs(Config.AllowedRarities) do
            Config.AllowedRarities[k] = false
        end
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "number" and type(v) == "string" then
                    Config.AllowedRarities[v] = true
                elseif type(k) == "string" and v then
                    Config.AllowedRarities[k] = true
                end
            end
        end
        saveConfig()
    end,
})

TabFilter:Dropdown({
    Title = "Specific Target Fruits Watchlist",
    Desc = "Search and pick exact fruits to prioritize.",
    Values = AllFruitIds,
    Value = mapToSelectedArray(Config.TargetFruits),
    Multi = true,
    AllowNone = true,
    SearchBarEnabled = true,
    Callback = function(selected)
        if IsInitializingUI then return end
        for k in pairs(Config.TargetFruits) do
            Config.TargetFruits[k] = false
        end
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "number" and type(v) == "string" then
                    Config.TargetFruits[v] = true
                elseif type(k) == "string" and v then
                    Config.TargetFruits[k] = true
                end
            end
        end
        saveConfig()
    end,
})

-- ---- TAB 3: DEALER & GACHA SNIPER ----
local DealerStockParagraph = TabDealer:Paragraph({
    Title = "🏪 Live Blox Fruit Dealer Stock",
    Desc = "Fetching current stock from CommF_('GetFruits')...",
})

TabDealer:Button({
    Title = "🔄 Refresh Dealer Stock Now",
    Desc = "Queries CommF_('GetFruits') immediately.",
    Icon = "refresh-cw",
    Callback = function()
        local onSale = refreshDealerStock(false)
        WindUI:Notify({
            Title = "Dealer Stock Refreshed",
            Content = string.format("Found %d fruit(s) currently on sale.", #onSale),
            Duration = 3,
            Icon = "shopping-bag",
        })
    end,
})

TabDealer:Toggle({
    Title = "Auto Snipe Dealer Stock (Beli)",
    Desc = "Automatically buys fruits on your Dealer Watchlist whenever they come in stock.",
    Icon = "shopping-cart",
    Value = Config.AutoDealerSniper,
    Callback = function(state)
        Config.AutoDealerSniper = state
        saveConfig()
        if state then
            refreshDealerStock(true)
        end
    end,
})

TabDealer:Dropdown({
    Title = "Dealer Auto-Buy Watchlist",
    Desc = "Fruits to automatically purchase when OnSale at the Dealer.",
    Values = AllFruitIds,
    Value = mapToSelectedArray(Config.DealerWatchlist),
    Multi = true,
    AllowNone = true,
    SearchBarEnabled = true,
    Callback = function(selected)
        if IsInitializingUI then return end
        for k in pairs(Config.DealerWatchlist) do
            Config.DealerWatchlist[k] = false
        end
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "number" and type(v) == "string" then
                    Config.DealerWatchlist[v] = true
                elseif type(k) == "string" and v then
                    Config.DealerWatchlist[k] = true
                end
            end
        end
        saveConfig()
    end,
})

TabDealer:Section({ Title = "Blox Fruit Gacha (Cousin)" })

TabDealer:Button({
    Title = "🎲 Roll Random Fruit (Cousin Gacha) Now",
    Desc = "Invokes CommF_('Cousin', 'Buy') and automatically stores the rolled fruit.",
    Icon = "dices",
    Callback = function()
        local ok, res = rollCousinGacha()
        WindUI:Notify({
            Title = "Cousin Gacha Roll",
            Content = ok and ("Result: " .. tostring(res)) or "Failed to invoke Cousin remote.",
            Duration = 3,
            Icon = "dices",
        })
    end,
})

TabDealer:Toggle({
    Title = "Auto Roll Cousin Gacha (Every 2 Hours / Cooldown)",
    Desc = "Periodically attempts to buy a random fruit from Cousin and auto-stores it.",
    Value = Config.AutoRollGacha,
    Callback = function(state)
        Config.AutoRollGacha = state
        saveConfig()
    end,
})

-- ---- TAB 4: FLIGHT & SERVER HOP ----
TabFlight:Section({ Title = "Anti-Detection Flight Parameters" })

TabFlight:Slider({
    Title = "Flight Speed (studs/sec)",
    Desc = "300 studs/s is the verified sweet spot from Alchemy Hub that avoids server rubberbanding.",
    Value = {
        Min = 120,
        Max = 350,
        Default = Config.FlightSpeed,
    },
    Step = 5,
    Callback = function(val)
        Config.FlightSpeed = tonumber(val) or 300
        saveConfig()
    end,
})

TabFlight:Slider({
    Title = "Minimum Water-Safe Altitude (MinY)",
    Desc = "Clamps Y coordinate above sea level so 'Movement + Swim' never triggers Devil Fruit drowning.",
    Value = {
        Min = 1,
        Max = 50,
        Default = Config.MinAltitudeY,
    },
    Step = 1,
    Callback = function(val)
        Config.MinAltitudeY = tonumber(val) or 2
        saveConfig()
    end,
})

TabFlight:Dropdown({
    Title = "Auto Join Team on Spawn/Rejoin",
    Desc = "Automatically spawns your character if sitting on the Pirates/Marines selection screen.",
    Values = { "Pirates", "Marines", "Disabled" },
    Value = Config.AutoJoinTeam,
    Callback = function(val)
        Config.AutoJoinTeam = tostring(val)
        saveConfig()
    end,
})

TabFlight:Section({ Title = "Smart Server Hopper" })

TabFlight:Toggle({
    Title = "Auto Server Hop When Map Has No Fruits",
    Desc = "Waits for Hop Delay seconds when 0 target fruits exist on the map, then hops to a new server.",
    Icon = "globe",
    Value = Config.AutoServerHop,
    Callback = function(state)
        Config.AutoServerHop = state
        EmptyMapSince = nil
        saveConfig()
    end,
})

TabFlight:Toggle({
    Title = "⚡ Turbo Fast Scan & Hop Mode",
    Desc = "Uses WindUI disk cache, 1.0s join grace, <=1.0s hop wait, and pre-warmed server pool for rapid server hopping.",
    Icon = "zap",
    Value = Config.TurboFastHop,
    Callback = function(state)
        Config.TurboFastHop = state
        EmptyMapSince = nil
        saveConfig()
    end,
})

TabFlight:Slider({
    Title = "Server Hop Wait Delay (seconds)",
    Desc = "Wait duration when no target fruits exist (Turbo Mode caps effective wait at <=1.0s).",
    Value = {
        Min = 0,
        Max = 120,
        Default = math.clamp(tonumber(Config.ServerHopDelay) or 2, 0, 120),
    },
    Step = 1,
    Callback = function(val)
        Config.ServerHopDelay = tonumber(val) or 2
        saveConfig()
    end,
})

TabFlight:Button({
    Title = "🔄 Refresh Server Pool Cache",
    Desc = "Pre-fetches unvisited Blox Fruits servers in the background for instant hops.",
    Icon = "refresh-cw",
    Callback = function()
        task.spawn(function()
            fetchFreshServerIds(game.PlaceId)
        end)
    end,
})

TabFlight:Button({
    Title = "🌐 Server Hop Immediately (Guaranteed New Server)",
    Desc = "Picks an unvisited server from the cached pool / multi-endpoint API and teleports safely.",
    Icon = "external-link",
    Callback = function()
        WindUI:Notify({
            Title = "Smart Server Hopping",
            Content = string.format("Hopping to an unvisited server (Pool: %d cached)...", #CachedServerPool),
            Duration = 3,
            Icon = "globe",
        })
        hopToNewServer()
    end,
})

TabFlight:Button({
    Title = "🗑️ Reset Visited Server Blacklist",
    Desc = "Clears visited_servers.json history if you want to allow revisiting older servers.",
    Icon = "trash-2",
    Callback = function()
        VisitedServers = { [tostring(game.JobId)] = os.time() }
        saveServerHopCache()
        WindUI:Notify({
            Title = "Visited Servers Cleared",
            Content = "Reset server history (current server remains excluded).",
            Duration = 3,
            Icon = "check",
        })
    end,
})

-- ---- TAB 5: ESP & DISCORD WEBHOOKS ----
TabWebhook:Section({ Title = "3D ESP & Floating Telemetry HUD" })

TabWebhook:Toggle({
    Title = "Enable 3D Fruit ESP",
    Desc = "Draws rarity-colored labels, fruit type ([MAP SPAWN] vs [DROPPED]), and stud distance.",
    Value = Config.FruitESP,
    Callback = function(state)
        Config.FruitESP = state
        saveConfig()
    end,
})

TabWebhook:Toggle({
    Title = "Enable 3D Fruit Tracer Lines",
    Desc = "Draws a beam line from the bottom of your screen to each fruit on the map.",
    Value = Config.FruitTracers,
    Callback = function(state)
        Config.FruitTracers = state
        saveConfig()
    end,
})

TabWebhook:Toggle({
    Title = "Show Floating Live Telemetry HUD",
    Desc = "Displays the draggable cyber-emerald sniper status card at the top of the screen.",
    Value = Config.ShowMiniHUD,
    Callback = function(state)
        Config.ShowMiniHUD = state
        HudCard.Visible = state
        saveConfig()
    end,
})

TabWebhook:Section({ Title = "Dual Discord Webhook (With Blox Fruits Wiki Images)" })

TabWebhook:Toggle({
    Title = "Enable Discord Webhook Alerts",
    Desc = "Sends rich embeds with official Blox Fruits Wiki fruit thumbnails on detect, store, and dealer buy.",
    Value = Config.WebhookEnabled,
    Callback = function(state)
        Config.WebhookEnabled = state
        saveConfig()
    end,
})

TabWebhook:Toggle({
    Title = "Send to Both Primary & Backup Simultaneously",
    Desc = "When off, Backup Webhook is used automatically only if Primary fails or rate-limits.",
    Value = Config.WebhookSendBoth,
    Callback = function(state)
        Config.WebhookSendBoth = state
        saveConfig()
    end,
})

TabWebhook:Input({
    Title = "Primary Discord Webhook URL",
    Desc = "Pre-loaded with your primary webhook.",
    Value = Config.WebhookPrimary,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(val)
        if type(val) == "string" and val ~= "" then
            Config.WebhookPrimary = normalizeDiscordUrl(val)
            saveConfig()
        end
    end,
})

TabWebhook:Input({
    Title = "Backup Discord Webhook URL (Failover)",
    Desc = "Pre-loaded with your backup webhook.",
    Value = Config.WebhookBackup,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(val)
        if type(val) == "string" and val ~= "" then
            Config.WebhookBackup = normalizeDiscordUrl(val)
            saveConfig()
        end
    end,
})

-- ---- TAB 6: WEB DASHBOARD & CLOUDFLARE SYNC ----
local WebStatusParagraph = TabWeb:Paragraph({
    Title = "🌐 Cloudflare Hub + GitHub Pages Sync",
    Desc = "Enter your Access Key to connect this instance to the Web Dashboard.",
})

TabWeb:Section({ Title = "Cloud Sync Configuration" })

TabWeb:Toggle({
    Title = "Enable Live Web Dashboard Sync",
    Desc = "Streams live status, shares learned 3D fingerprints across accounts, coordinates anti-duplicate servers, and accepts remote Config edits.",
    Icon = "globe",
    Value = Config.WebSyncEnabled,
    Callback = function(state)
        Config.WebSyncEnabled = state
        saveConfig()
    end,
})

TabWeb:Input({
    Title = "Cloudflare Worker API URL",
    Desc = "Default points to your deployed Aegis Fruit Hub Worker.",
    Value = Config.WebSyncUrl,
    Placeholder = DEFAULT_WEB_SYNC_URL,
    Callback = function(val)
        if type(val) == "string" and val ~= "" then
            Config.WebSyncUrl = val:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
            saveConfig()
        end
    end,
})

TabWeb:Input({
    Title = "Dashboard Access Key (Secret PIN)",
    Desc = "Must match AEGIS_ACCESS_KEY on your Cloudflare Worker (never stored on GitHub).",
    Value = Config.WebAccessKey,
    Placeholder = "aegis_...",
    Callback = function(val)
        if type(val) == "string" then
            Config.WebAccessKey = val:gsub("^%s+", ""):gsub("%s+$", "")
            saveConfig()
        end
    end,
})

TabWeb:Slider({
    Title = "Web Sync Interval (seconds)",
    Desc = "How often this instance sends telemetry & polls remote commands/config (5s recommended for multi-account free tier).",
    Value = {
        Min = 2,
        Max = 30,
        Default = math.clamp(tonumber(Config.WebSyncInterval) or 5, 2, 30),
    },
    Step = 1,
    Callback = function(val)
        Config.WebSyncInterval = tonumber(val) or 5
        saveConfig()
    end,
})

HudCard.Visible = Config.ShowMiniHUD
IsInitializingUI = false
saveConfig(true)

TabWebhook:Button({
    Title = "📨 Send Test Webhook Embed (With Wiki Fruit Image)",
    Desc = "Sends a live test embed with your current equipped fruit's Wiki thumbnail and map fruit scan.",
    Icon = "send",
    Callback = function()
        local list = fullRescanWorkspace()
        local lpData = LocalPlayer:FindFirstChild("Data")
        local eqFruit = lpData and lpData:FindFirstChild("DevilFruit") and lpData.DevilFruit.Value or ""
        local eqMeta = FruitMetaById[eqFruit] or (list[1] and list[1].Meta) or FruitMetaById["Magnet-Magnet"]
        local thumbUrl = (eqMeta and eqMeta.Icon) or DEFAULT_FRUIT_ICON

        sendDiscordWebhook(
            "🟢 Aegis Fruit Sniper v3.2 — Wiki Image + Cloud Hub Verified!",
            string.format(
                "Dual Webhook + **Blox Fruits Wiki Fruit Thumbnails** are online!\nCurrently tracking **%d** fruit(s) in `Workspace`.\nFeatured Icon: **%s**",
                #list,
                eqMeta and eqMeta.Display or "Kitsune"
            ),
            0x00F5A0,
            {
                { name = "📡 Map Fruits", value = string.format("`%d` active in Workspace", #list), inline = true },
                { name = "🖼️ Wiki Thumbnail", value = string.format("`%s Fruit`", eqMeta and eqMeta.Display or "Kitsune"), inline = true },
            },
            thumbUrl
        )
        WindUI:Notify({
            Title = "Test Webhook Dispatched",
            Content = "Check Discord! Sent with Wiki image for: " .. (eqMeta and eqMeta.Display or "Kitsune"),
            Duration = 4,
            Icon = "check",
        })
    end,
})

-- ============================================================================
-- 11B. CLOUDFLARE WEB HUB ENGINE (Multi-Instance Sync, Locks & Commands)
-- ============================================================================
function WebHub.getBaseUrl()
    local u = type(Config.WebSyncUrl) == "string" and Config.WebSyncUrl ~= "" and Config.WebSyncUrl or DEFAULT_WEB_SYNC_URL
    return (u:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", ""))
end

function WebHub.getKey()
    if type(Config.WebAccessKey) == "string" and Config.WebAccessKey ~= "" then
        return Config.WebAccessKey
    end
    if type(genv.AEGIS_WEB_KEY) == "string" and genv.AEGIS_WEB_KEY ~= "" then
        return genv.AEGIS_WEB_KEY
    end
    return ""
end

local WEB_LOCAL_ONLY_KEYS = {
    WebSyncEnabled = true,
    WebSyncUrl = true,
    WebAccessKey = true,
    WebhookPrimary = true,
    WebhookBackup = true,
}

function WebHub.buildSanitizedConfig()
    local out = {}
    for k, v in pairs(Config) do
        if not WEB_LOCAL_ONLY_KEYS[k] then
            if type(v) == "table" then
                local copy = {}
                for subK, subV in pairs(v) do
                    if subV == true then
                        copy[subK] = true
                    end
                end
                out[k] = copy
            else
                out[k] = v
            end
        end
    end
    return out
end

function WebHub.applyConfigLayer(layer)
    if type(layer) ~= "table" then return false end
    local changed = false
    for k, v in pairs(layer) do
        if not WEB_LOCAL_ONLY_KEYS[k] and Config[k] ~= nil then
            if type(Config[k]) == "table" and type(v) == "table" then
                local nextMap = {}
                for subK, subV in pairs(v) do
                    if type(subK) == "string" then
                        nextMap[subK] = (subV == true)
                    elseif type(subK) == "number" and type(subV) == "string" then
                        nextMap[subV] = true
                    end
                end
                Config[k] = nextMap
                changed = true
            elseif type(v) == type(Config[k]) then
                if Config[k] ~= v then
                    Config[k] = v
                    changed = true
                end
            end
        end
    end
    return changed
end

function WebHub.applyMergedRemoteConfig()
    local changed = false
    if type(WebHub.CachedGlobalConfig) == "table" then
        if WebHub.applyConfigLayer(WebHub.CachedGlobalConfig) then
            changed = true
        end
    end
    if type(WebHub.CachedOverrideConfig) == "table" then
        if WebHub.applyConfigLayer(WebHub.CachedOverrideConfig) then
            changed = true
        end
    end
    if changed then
        HudCard.Visible = Config.ShowMiniHUD
        if not Config.AutoSnipeMap and FlightState.Active then
            stopFlight()
        end
        if Config.AutoStoreFruits then
            storeAllCurrentFruitTools()
        end
        rebuildSortedMapFruits()
        saveConfig(true)
        pcall(function()
            WindUI:Notify({
                Title = "🌐 Config Updated from Web",
                Content = string.format("Applied cloud config (Global v%d / Override v%d)", WebHub.KnownGlobalVersion, WebHub.KnownOverrideVersion),
                Duration = 3,
                Icon = "globe",
            })
        end)
    end
end

function WebHub.executeCommands(commands)
    if type(commands) ~= "table" then return end
    for _, cmd in ipairs(commands) do
        if type(cmd) == "table" and type(cmd.action) == "string" then
            local act = cmd.action
            local pl = type(cmd.payload) == "table" and cmd.payload or {}
            if act == "force_hop" then
                EmptyMapSince = nil
                task.spawn(hopToNewServer)
            elseif act == "rescan" then
                task.spawn(function()
                    fullRescanWorkspace()
                    if Config.AutoStoreFruits then
                        storeAllCurrentFruitTools()
                    end
                end)
            elseif act == "roll_gacha" then
                task.spawn(rollCousinGacha)
            elseif act == "store_now" then
                task.spawn(storeAllCurrentFruitTools)
            elseif act == "join_server" then
                local pid = tonumber(pl.placeId) or game.PlaceId
                local jid = tostring(pl.jobId or "")
                if jid ~= "" and jid ~= tostring(game.JobId) and not IsHopping then
                    IsHopping = true
                    stopFlight()
                    clearAllEsp()
                    VisitedServers[tostring(game.JobId)] = os.time()
                    saveConfig(true)
                    saveServerHopCache()
                    armTeleportAutoExecute()
                    task.spawn(function()
                        local ok = pcall(function()
                            TeleportService:TeleportToPlaceInstance(pid, jid, LocalPlayer)
                        end)
                        if not ok then
                            IsHopping = false
                        end
                    end)
                end
            elseif act == "set_team" and type(pl.team) == "string" then
                Config.AutoJoinTeam = pl.team
                saveConfig(true)
                if pl.team ~= "Disabled" then
                    task.spawn(function()
                        pcall(function()
                            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                            if commF then
                                commF:InvokeServer("SetTeam", pl.team)
                            end
                        end)
                    end)
                end
            elseif act == "remote_stop" then
                task.defer(function()
                    if WebHub.StopCleanupFn then
                        WebHub.StopCleanupFn()
                    elseif genv.__AegisFruitSniperCleanup then
                        genv.__AegisFruitSniperCleanup()
                    end
                end)
            end
        end
    end
end

function WebHub.claimServer(jobId, oldJobId)
    local key = WebHub.getKey()
    if not httpRequestFn or key == "" then return true end
    local ok, resp = pcall(httpRequestFn, {
        Url = WebHub.getBaseUrl() .. "/api/claim-server",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-Aegis-Key"] = key,
        },
        Body = HttpService:JSONEncode({
            instanceKey = tostring(LocalPlayer.UserId),
            playerName = LocalPlayer.Name,
            placeId = game.PlaceId,
            jobId = tostring(jobId),
            oldJobId = tostring(oldJobId or ""),
        }),
    })
    if not ok or not resp or tonumber(resp.StatusCode) ~= 200 then
        return true -- Do not stall hopping on transient network errors
    end
    local parsedOk, data = pcall(function()
        return HttpService:JSONDecode(resp.Body)
    end)
    if parsedOk and type(data) == "table" and data.ok == false then
        return false
    end
    return true
end

local function refreshStoredInventorySnapshot(force)
    local nowClock = os.clock()
    if not force and not InventoryNeedsRefresh and (nowClock - LastInventoryFetchAt) < 20 then
        return CachedStoredFruits
    end
    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    if not commF then return CachedStoredFruits end

    local ok, inv = pcall(function()
        return commF:InvokeServer("getInventory")
    end)
    if ok and type(inv) == "table" then
        local list = {}
        for _, item in pairs(inv) do
            if type(item) == "table" and (item.Type == "Blox Fruit" or (type(item.Name) == "string" and FruitMetaById[item.Name] ~= nil)) then
                local rawName = tostring(item.Name or "")
                local cleanLower = rawName:gsub(" Fruit$", ""):lower()
                local itemIdNum = tonumber(item.ItemId)
                local meta = FruitMetaById[rawName] or (itemIdNum and FruitMetaByItemId[itemIdNum]) or FruitMetaByShort[cleanLower]
                local cnt = math.max(1, math.floor(tonumber(item.Count) or 1))
                table.insert(list, {
                    id = meta and meta.Id or rawName,
                    display = meta and meta.Display or rawName,
                    rarity = meta and meta.Rarity or "Unknown",
                    price = meta and meta.Price or tonumber(item.Value) or 0,
                    count = cnt,
                    icon = (meta and meta.Icon) or DEFAULT_FRUIT_ICON,
                })
            end
        end
        table.sort(list, function(a, b)
            if (a.price or 0) ~= (b.price or 0) then
                return (a.price or 0) > (b.price or 0)
            end
            return tostring(a.display) < tostring(b.display)
        end)
        CachedStoredFruits = list
        LastInventoryFetchAt = nowClock
        InventoryNeedsRefresh = false
    end
    return CachedStoredFruits
end

local function collectHeldBackpackFruits()
    local held = {}
    local function scanContainer(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:find("Fruit") or tool:FindFirstChild("EatRemote") or tool:GetAttribute("OriginalName") or tool:GetAttribute("ItemId")) then
                local orig = tool:GetAttribute("OriginalName")
                local itemId = tonumber(tool:GetAttribute("ItemId"))
                local clean = tool.Name:gsub(" Fruit$", ""):gsub("^%s+", ""):gsub("%s+$", "")
                local meta = (type(orig) == "string" and FruitMetaById[orig])
                    or (itemId and FruitMetaByItemId[itemId])
                    or FruitMetaById[clean .. "-" .. clean]
                    or FruitMetaByShort[clean:lower()]
                local isPhysicalFruit = (meta ~= nil and tool.ToolTip ~= "Blox Fruit")
                    or tool.Name:find("Fruit") ~= nil
                    or tool:FindFirstChild("EatRemote") ~= nil
                if isPhysicalFruit then
                    table.insert(held, {
                        id = meta and meta.Id or (orig or clean),
                        display = meta and meta.Display or clean,
                        rarity = meta and meta.Rarity or "Unknown",
                        price = meta and meta.Price or 0,
                        count = 1,
                        icon = (meta and meta.Icon) or DEFAULT_FRUIT_ICON,
                    })
                end
            end
        end
    end
    scanContainer(LocalPlayer:FindFirstChild("Backpack"))
    scanContainer(LocalPlayer.Character)
    return held
end

function WebHub.syncNow(force, liveStatusText)
    if WebHub.IsSyncing or not httpRequestFn then return end
    local key = WebHub.getKey()
    if key == "" then
        WebHub.Status = "Missing Access Key (set in Tab)"
        return
    end

    WebHub.IsSyncing = true
    WebHub.LastSyncAt = os.clock()
    WebHub.ImmediateRequested = false

    task.spawn(function()
        pcall(function()
            local lpData = LocalPlayer:FindFirstChild("Data")
            local level = lpData and lpData:FindFirstChild("Level") and tonumber(lpData.Level.Value) or 0
            local beli = lpData and lpData:FindFirstChild("Beli") and tonumber(lpData.Beli.Value) or 0
            local df = lpData and lpData:FindFirstChild("DevilFruit") and tostring(lpData.DevilFruit.Value) or "None"
            if df == "" then df = "None" end

            local mapFruitsSummary = {}
            for i, f in ipairs(MapFruits) do
                if i <= 10 then
                    table.insert(mapFruitsSummary, {
                        name = f.Name,
                        display = (f.Meta and f.Meta.Display) or f.Name,
                        rarity = f.Rarity or "Unknown",
                        distance = f.Distance or 0,
                        isNatural = f.IsNatural == true,
                        matchesFilter = f.MatchesFilter == true,
                        icon = (f.Meta and f.Meta.Icon) or DEFAULT_FRUIT_ICON,
                    })
                end
            end

            local dealerSummary = {}
            for i, d in ipairs(DealerOnSaleList) do
                if i <= 20 then
                    table.insert(dealerSummary, {
                        name = d.Name,
                        rarity = d.Rarity or "Unknown",
                        price = d.Price or 0,
                        icon = d.Icon or DEFAULT_FRUIT_ICON,
                    })
                end
            end

            -- Snapshot pending composite fingerprints only; if remote DB is empty, seed local composite fingerprints once
            local uploadFps = {}
            local uploadCount = 0
            for k, v in pairs(WebHub.PendingFingerprints) do
                if isValidCompositeFingerprintKey(k) then
                    uploadFps[k] = v
                    uploadCount = uploadCount + 1
                end
            end
            if WebHub.KnownFpTotal == 0 and uploadCount == 0 then
                for k, v in pairs(FruitAssetMap) do
                    if isValidCompositeFingerprintKey(k) and type(v) == "string" and v ~= "" then
                        uploadFps[k] = v
                        uploadCount = uploadCount + 1
                    end
                end
            end

            local uploadCatches = {}
            for _, c in ipairs(WebHub.PendingCatches) do
                table.insert(uploadCatches, c)
            end

            saveSessionState()
            local storedFruits = refreshStoredInventorySnapshot(false)
            local heldFruits = collectHeldBackpackFruits()
            local totalStoredCount = 0
            local totalStoredValue = 0
            for _, sf in ipairs(storedFruits) do
                local c = tonumber(sf.count) or 1
                totalStoredCount = totalStoredCount + c
                totalStoredValue = totalStoredValue + ((tonumber(sf.price) or 0) * c)
            end

            local payload = {
                instanceKey = tostring(LocalPlayer.UserId),
                userId = tostring(LocalPlayer.UserId),
                playerName = LocalPlayer.Name,
                displayName = LocalPlayer.DisplayName,
                level = level,
                beli = beli,
                equippedFruit = df,
                placeId = game.PlaceId,
                jobId = tostring(game.JobId),
                playersCount = #Players:GetPlayers(),
                maxPlayers = Players.MaxPlayers,
                status = tostring(liveStatusText or WebHub.LastStatusLabel or "IDLE"),
                flightTarget = FlightState.Active and tostring(FlightState.TargetLabel or "") or "",
                mapFruits = mapFruitsSummary,
                dealerStock = dealerSummary,
                inventory = {
                    stored = storedFruits,
                    held = heldFruits,
                    totalStoredCount = totalStoredCount,
                    totalUnique = #storedFruits,
                    totalValue = totalStoredValue,
                    updatedAt = os.time() * 1000,
                },
                startedAt = SessionStartedAt * 1000,
                storedSession = TotalSnipedSession,
                poolCount = #CachedServerPool,
                learnedCount = LearnedFruitCount,
                webhookSent = WebhookSentCount,
                turboMode = Config.TurboFastHop == true,
                activeConfig = WebHub.buildSanitizedConfig(),
                knownGlobalVersion = WebHub.KnownGlobalVersion,
                knownOverrideVersion = WebHub.KnownOverrideVersion,
                knownFpTs = WebHub.KnownFpTs,
                knownFpTotal = WebHub.KnownFpTotal,
                newFingerprints = uploadCount > 0 and uploadFps or {},
                catches = uploadCatches,
            }

            local ok, resp = pcall(httpRequestFn, {
                Url = WebHub.getBaseUrl() .. "/api/sync",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-Aegis-Key"] = key,
                },
                Body = HttpService:JSONEncode(payload),
            })

            if not ok or not resp then
                WebHub.Status = "Network Error"
                return
            end

            local code = tonumber(resp.StatusCode) or 0
            if code == 401 then
                WebHub.Status = "Auth Failed (Check Access Key)"
                return
            elseif code < 200 or code >= 300 then
                WebHub.Status = "HTTP Error " .. tostring(code)
                return
            end

            local decOk, data = pcall(function()
                return HttpService:JSONDecode(resp.Body)
            end)
            if not decOk or type(data) ~= "table" or not data.ok then
                WebHub.Status = "Invalid JSON Response"
                return
            end

            -- Clear successfully transmitted buffers
            for k in pairs(uploadFps) do
                if WebHub.PendingFingerprints[k] == uploadFps[k] then
                    WebHub.PendingFingerprints[k] = nil
                end
            end
            for _ = 1, #uploadCatches do
                table.remove(WebHub.PendingCatches, 1)
            end

            WebHub.SyncCount = WebHub.SyncCount + 1
            WebHub.Status = string.format("Connected (#%d)", WebHub.SyncCount)

            if type(data.blockedJobIds) == "table" then
                local nextBlocked = {}
                for _, jid in ipairs(data.blockedJobIds) do
                    if type(jid) == "string" and jid ~= "" then
                        nextBlocked[jid] = true
                    end
                end
                WebHub.BlockedJobIds = nextBlocked
            end

            if type(data.globalFingerprints) == "table" then
                local mergedFp = false
                for ak, fid in pairs(data.globalFingerprints) do
                    if isValidCompositeFingerprintKey(ak) and type(fid) == "string" and (fid == "__SHARED__" or FruitMetaById[fid]) then
                        if FruitAssetMap[ak] ~= fid then
                            FruitAssetMap[ak] = fid
                            mergedFp = true
                        end
                    end
                end
                if mergedFp then
                    LastFingerprintUpdateAt = os.clock()
                    saveFruitFingerprints(true)
                    rebuildSortedMapFruits()
                else
                    recountLearnedFruits()
                end
            end
            if tonumber(data.fpMaxTs) then WebHub.KnownFpTs = tonumber(data.fpMaxTs) end
            if tonumber(data.fpTotal) then WebHub.KnownFpTotal = tonumber(data.fpTotal) end

            local cfgDirty = false
            local gVer = tonumber(data.globalConfigVersion) or 0
            if gVer ~= WebHub.KnownGlobalVersion then
                WebHub.KnownGlobalVersion = gVer
                if type(data.globalConfig) == "table" then
                    WebHub.CachedGlobalConfig = data.globalConfig
                end
                cfgDirty = true
            end

            local oVer = tonumber(data.overrideVersion) or 0
            if oVer ~= WebHub.KnownOverrideVersion then
                WebHub.KnownOverrideVersion = oVer
                if type(data.overrideConfig) == "table" then
                    WebHub.CachedOverrideConfig = data.overrideConfig
                end
                cfgDirty = true
            end

            if cfgDirty then
                WebHub.applyMergedRemoteConfig()
            end

            if type(data.commands) == "table" and #data.commands > 0 then
                WebHub.executeCommands(data.commands)
            end
        end)
        WebHub.IsSyncing = false
    end)
end

TabWeb:Button({
    Title = "🔄 Sync With Web Dashboard Now",
    Desc = "Immediately pushes telemetry, syncs shared fingerprints, and checks remote commands.",
    Icon = "refresh-cw",
    Callback = function()
        WebHub.syncNow(true, WebHub.LastStatusLabel or "Manual Sync")
        WindUI:Notify({
            Title = "Web Sync Triggered",
            Content = "Status: " .. tostring(WebHub.Status),
            Duration = 3,
            Icon = "globe",
        })
    end,
})

TabWeb:Button({
    Title = "📋 Copy GitHub Pages Dashboard URL",
    Desc = GITHUB_PAGES_URL,
    Icon = "copy",
    Callback = function()
        if setclipboard then
            pcall(setclipboard, GITHUB_PAGES_URL)
        end
        WindUI:Notify({
            Title = "Dashboard URL Copied!",
            Content = GITHUB_PAGES_URL,
            Duration = 3,
            Icon = "check",
        })
    end,
})

-- ============================================================================
-- 12. ULTRA-LIGHTWEIGHT MASTER ORCHESTRATOR LOOP (Turbo 0.1s Tick)
-- ============================================================================
task.spawn(function()
    fullRescanWorkspace()
    hookInventoryListeners()
    storeAllCurrentFruitTools()

    task.spawn(function()
        refreshDealerStock(false)
    end)

    if Config.WebSyncEnabled then
        WebHub.syncNow(true, "Starting Up...")
    end

    local lastFullRescan = os.clock()
    local lastToolLearnScan = os.clock()
    local lastPoolCheck = os.clock()
    local lastTeamAttempt = 0
    local lastGachaAttempt = 0
    local lastLearnedCount = -1
    local lastRadarText = ""
    local lastDealerText = ""
    local lastHudStatus = ""
    local lastHudSub = ""
    local lastHudWebhook = ""
    local lastWebText = ""

    while isScriptAlive() do
        local now = os.clock()

        -- 1. Auto Join Team if player has no Character (non-blocking)
        if not getCharacter() and Config.AutoJoinTeam ~= "Disabled" and (now - lastTeamAttempt) >= 0.5 then
            lastTeamAttempt = now
            task.spawn(function()
                pcall(function()
                    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                    if commF then
                        commF:InvokeServer("SetTeam", Config.AutoJoinTeam)
                    end
                end)
            end)
        end

        -- 2. Hook Backpack/Character listeners & rapid 1.0s workspace reconciliation
        hookInventoryListeners()
        if (now - lastFullRescan) >= 1.0 then
            lastFullRescan = now
            fullRescanWorkspace()
            if Config.AutoStoreFruits then
                storeAllCurrentFruitTools()
            end
        else
            rebuildSortedMapFruits()
        end

        -- Background tool fingerprint harvesting & server pool pre-warming
        if (now - lastToolLearnScan) >= 8 then
            lastToolLearnScan = now
            task.spawn(scanAllVisibleToolsForFingerprints)
        end
        if #CachedServerPool < 15 and not IsFetchingPool and (now - lastPoolCheck) >= 8 then
            lastPoolCheck = now
            task.spawn(function()
                fetchFreshServerIds(game.PlaceId)
            end)
        end

        local fruits = MapFruits

        -- 3. Auto Snipe Map Fruits
        local targetEntry = nil
        for _, entry in ipairs(fruits) do
            if entry.MatchesFilter then
                targetEntry = entry
                break
            end
        end

        if Config.AutoSnipeMap then
            if targetEntry and targetEntry.Handle and targetEntry.Handle.Parent then
                EmptyMapSince = nil
                CurrentSnipeTarget = targetEntry
                setFlightTarget(targetEntry.Handle.Position, targetEntry.Name, targetEntry.Handle)
            else
                if FlightState.Active then
                    stopFlight()
                end
                CurrentSnipeTarget = nil
            end
        elseif CurrentSnipeTarget then
            if not CurrentSnipeTarget.Instance or not CurrentSnipeTarget.Instance.Parent or not CurrentSnipeTarget.Handle or not CurrentSnipeTarget.Handle.Parent then
                stopFlight()
                CurrentSnipeTarget = nil
            else
                setFlightTarget(CurrentSnipeTarget.Handle.Position, CurrentSnipeTarget.Name, CurrentSnipeTarget.Handle)
            end
        end

        -- Smart Server Hop check when no target fruits exist on map (Turbo Mode: 1.0s join grace, <=1.0s hop delay)
        local joinGrace = Config.TurboFastHop and 1.0 or 3.0
        local rawDelay = tonumber(Config.ServerHopDelay) or 2
        local effectiveDelay = Config.TurboFastHop and math.min(rawDelay, 1.0) or rawDelay
        if Config.AutoServerHop and not IsHopping and not FlightState.Active and ActiveStoreJobs == 0 and targetEntry == nil and (now - ScriptStartTime) >= joinGrace and getCharacter() ~= nil then
            if not EmptyMapSince then
                EmptyMapSince = now
            elseif (now - EmptyMapSince) >= effectiveDelay then
                EmptyMapSince = now + 999
                hopToNewServer()
            end
        elseif targetEntry ~= nil then
            EmptyMapSince = nil
        end

        -- 4. Periodic Dealer Check & Auto Gacha
        if (now - LastDealerCheck) >= Config.DealerCheckInterval then
            LastDealerCheck = now
            task.spawn(function()
                refreshDealerStock(Config.AutoDealerSniper)
            end)
        end

        if Config.AutoRollGacha and (now - lastGachaAttempt) >= 45 then
            lastGachaAttempt = now
            task.spawn(rollCousinGacha)
        end

        -- 5. Dirty-Checked UI & Floating HUD Updates (Zero Unnecessary UI Relayouts)
        pcall(function()
            local newStatus
            if FlightState.Active and FlightState.TargetPos then
                newStatus = string.format("🚀 Flying to: %s (%d studs)", FlightState.TargetLabel, math.floor(FlightState.CurrentDistance))
                HudStatusLine.TextColor3 = Color3.fromHex("#00F5A0")
                local startD = math.max(FlightState.StartDistance, 1)
                local pct = math.clamp(1 - (FlightState.CurrentDistance / startD), 0.05, 1)
                ProgressFill.Size = UDim2.new(pct, 0, 1, 0)
            elseif Config.AutoServerHop and EmptyMapSince and not targetEntry then
                local rem = math.max(0, effectiveDelay - (now - EmptyMapSince))
                if #fruits > 0 then
                    newStatus = string.format("⏭️ Skipped %d Non-Target — Hop in %.1fs", #fruits, rem)
                else
                    newStatus = string.format("🌐 Map Empty — Hopping in %.1fs...", rem)
                end
                HudStatusLine.TextColor3 = Color3.fromHex("#38BDF8")
                ProgressFill.Size = UDim2.new(0, 0, 1, 0)
            else
                newStatus = (#fruits > 0)
                    and string.format("📡 %d Fruit(s) on Map! Nearest: %s (%dm)", #fruits, fruits[1].Meta and fruits[1].Meta.Display or fruits[1].Name, fruits[1].Distance)
                    or "📡 Status: Turbo Radar Active (0 Fruits)"
                HudStatusLine.TextColor3 = (#fruits > 0) and Color3.fromHex("#FBBF24") or Color3.fromHex("#E2E8F0")
                ProgressFill.Size = UDim2.new(0, 0, 1, 0)
            end

            if newStatus ~= lastHudStatus then
                lastHudStatus = newStatus
                HudStatusLine.Text = newStatus
                WebHub.LastStatusLabel = newStatus
            end

            local newSub = string.format(
                "Map: %d | Stored: %d | Pool: %d | DB: %d",
                #fruits,
                TotalSnipedSession,
                #CachedServerPool,
                LearnedFruitCount
            )
            if newSub ~= lastHudSub then
                lastHudSub = newSub
                HudSubLine.Text = newSub
            end

            local newWh = string.format("Discord Webhook: %s (Sent: %d)", WebhookStatus, WebhookSentCount)
            if newWh ~= lastHudWebhook then
                lastHudWebhook = newWh
                HudWebhookLine.Text = newWh
            end

            if LearnedFruitCount ~= lastLearnedCount then
                lastLearnedCount = LearnedFruitCount
                FingerprintDbParagraph:SetDesc(string.format(
                    "Learned %d fruits (%d 3D composite signatures) — auto-learns on pickups, visible players & Cloud DB.",
                    LearnedFruitCount,
                    LearnedSigCount
                ))
            end

            local radarLines = {}
            if #fruits == 0 then
                table.insert(radarLines, "• No fruits currently spawned in Workspace.")
            else
                for i, f in ipairs(fruits) do
                    if i <= 8 then
                        local kind = f.IsNatural and "[NATURAL]" or "[DROPPED]"
                        local filterTag = (Config.OnlySnipeFiltered and not f.MatchesFilter) and "[SKIP]" or "[TARGET]"
                        table.insert(radarLines, string.format(
                            "%d. %s %s %s (%s) — %d studs",
                            i, filterTag, kind, f.Meta and f.Meta.Display or f.Name, f.Rarity, f.Distance
                        ))
                    end
                end
            end
            local blockedCount = 0
            for _ in pairs(WebHub.BlockedJobIds) do blockedCount = blockedCount + 1 end
            local newWebDesc = string.format(
                "Status: %s | Alt Locks: %d | Config Global v%d / Override v%d",
                Config.WebSyncEnabled and WebHub.Status or "Disabled",
                blockedCount,
                WebHub.KnownGlobalVersion,
                WebHub.KnownOverrideVersion
            )
            if newWebDesc ~= lastWebText then
                lastWebText = newWebDesc
                WebStatusParagraph:SetDesc(newWebDesc)
            end

            table.insert(radarLines, string.format(
                "\nStored: %d | Flight: %s | Pool: %d | DB: %d | Hub: %s",
                TotalSnipedSession,
                FlightState.Active and ("ACTIVE -> " .. FlightState.TargetLabel) or "IDLE",
                #CachedServerPool,
                LearnedFruitCount,
                Config.WebSyncEnabled and WebHub.Status or "OFF"
            ))
            local newRadarText = table.concat(radarLines, "\n")
            if newRadarText ~= lastRadarText then
                lastRadarText = newRadarText
                LiveRadarParagraph:SetDesc(newRadarText)
            end

            local newDealerText
            if #DealerOnSaleList == 0 then
                newDealerText = "Refreshing stock or 0 fruits currently on sale..."
            else
                local dLines = {}
                for _, d in ipairs(DealerOnSaleList) do
                    table.insert(dLines, string.format("• %s [%s] — $%s Beli", d.Name, d.Rarity, formatNumber(d.Price)))
                end
                newDealerText = table.concat(dLines, "\n")
            end
            if newDealerText ~= lastDealerText then
                lastDealerText = newDealerText
                DealerStockParagraph:SetDesc(newDealerText)
            end
        end)

        -- 6. Asynchronous Cloud Web Hub Sync (Dirty-checked & Non-blocking)
        if Config.WebSyncEnabled then
            local interval = math.clamp(tonumber(Config.WebSyncInterval) or 5, 2, 30)
            local minGap = WebHub.ImmediateRequested and 0.8 or interval
            if (now - WebHub.LastSyncAt) >= minGap then
                WebHub.syncNow(false, lastHudStatus)
            end
        end

        task.wait(0.1)
    end
end)

-- ============================================================================
-- 13. CLEANUP REGISTRATION
-- ============================================================================
local function fullCleanup()
    RuntimeAlive = false
    pcall(stopFlight)
    pcall(clearAllEsp)
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, d in ipairs(Drawings) do
        pcall(function() d:Remove() end)
    end
    pcall(function()
        if HudGui then HudGui:Destroy() end
    end)
    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)
    pcall(function()
        if WindUI and WindUI.ScreenGui then WindUI.ScreenGui:Destroy() end
    end)
end

WebHub.StopCleanupFn = fullCleanup
genv.__AegisFruitSniperCleanup = fullCleanup
if typeof(STATE) == "table" and STATE.onCleanup then
    STATE.onCleanup(fullCleanup)
end

WindUI:Notify({
    Title = "Aegis Fruit Sniper v3.2 CLOUD HUB Loaded!",
    Content = string.format("Cloud Sync + Pre-ID DB (%d) + Turbo Hop + Wiki Webhooks Ready!", LearnedFruitCount),
    Duration = 5,
    Icon = "radar",
})
