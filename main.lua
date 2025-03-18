-- Airstrike! Mod for Trailmakers, ticibi 2022
-- name: Airstrike!
-- author: ticibi
-- description: Enhanced airstrike system with improved performance and UI

-- Constants
local CONSTANTS = {
    DEFAULT_IMPACT_COUNT = 10,
    DEFAULT_COOLDOWN = 0,
    DEFAULT_STRIKE_INTERVAL = 25,
    DEFAULT_STRIKE_RADIUS = 50,
    DEFAULT_STRIKE_DELAY = 5,
    UI_UPDATE_INTERVAL = 0.1, -- 100ms
    FX_TYPES = {
        "PFB_PoisonCloud_Explosion",
        "PFB_Explosion_Large",
        "PFB_Explosion_Medium",
        "PFB_Explosion_Micro",
        "PFB_Explosion_SeatDeath",
        "PFB_Explosion_Small",
        "PFB_Explosion_XL",
    },
    INFO_TEXT = {
        "---- cooldown ----",
        "(in seconds)",
        "time to wait after calling in a strike",
        " ",
        "---- impact count ----",
        "number of explosions per strike",
        " ",
        "---- strike radius ----",
        "distance around target in which",
        "explosions will occur",
        " ",
        "---- strike interval ----",
        "(in milliseconds)",
        "time between explosions",
        " ",
        "---- strike delay ----",
        "(in seconds)",
        "wait time before strike begins",
    }
}

-- Player data management
local playerData = {}

local function initPlayerData(playerId)
    return {
        pvpEnabled = true,
        targetSelf = true,
        isBeingTargeted = false,
        state = "IDLE", -- IDLE, PRESTRIKE, ACTIVE, COOLDOWN
        impactCount = 0,
        strikeTimer = 0,
        stateTimer = 0,
        targetId = nil,
        fxIndex = 1,
        lastUpdate = 0,
        totalTime = 0,
    }
end

-- Event Handlers
tm.players.OnPlayerJoined.add(function(player)
    playerData[player.playerId] = initPlayerData(player.playerId)
    showHomePage(player.playerId)
end)

-- Main Update Loop
function update()
    local currentTime = os.clock()
    for _, player in pairs(tm.players.CurrentPlayers()) do
        local pid = player.playerId
        local pd = playerData[pid]
        
        if not pd then
            pd = initPlayerData(pid)
            playerData[pid] = pd
        end

        pd.totalTime = pd.totalTime + CONSTANTS.UI_UPDATE_INTERVAL
        
        if currentTime - pd.lastUpdate >= CONSTANTS.UI_UPDATE_INTERVAL then
            pd.lastUpdate = currentTime
            pd.strikeTimer = pd.strikeTimer + CONSTANTS.UI_UPDATE_INTERVAL
            
            if pd.state == "PRESTRIKE" then handlePrestrike(pid)
            elseif pd.state == "ACTIVE" then handleAirstrike(pid)
            elseif pd.state == "COOLDOWN" then handleCooldown(pid) end
            
            updateUI(pid)
        end
    end
end

-- State Handlers
function handlePrestrike(playerId)
    local pd = playerData[playerId]
    pd.stateTimer = pd.stateTimer - CONSTANTS.UI_UPDATE_INTERVAL
    
    if pd.stateTimer <= 0 then
        pd.state = "ACTIVE"
        pd.stateTimer = 0
        pd.impactCount = 0
    end
end

function handleAirstrike(playerId)
    local pd = playerData[playerId]
    
    if pd.strikeTimer >= CONSTANTS.DEFAULT_STRIKE_INTERVAL / 1000 then
        if pd.impactCount < CONSTANTS.DEFAULT_IMPACT_COUNT then
            local targetPos = tm.players.GetPlayerTransform(pd.targetId).GetPosition()
            local spawnPos = targetPos + getRandomVariance(CONSTANTS.DEFAULT_STRIKE_RADIUS)
            spawnExplosion(spawnPos, CONSTANTS.FX_TYPES[pd.fxIndex])
            pd.impactCount = pd.impactCount + 1
            pd.strikeTimer = 0
        else
            pd.state = "COOLDOWN"
            pd.stateTimer = CONSTANTS.DEFAULT_COOLDOWN
            playerData[pd.targetId].isBeingTargeted = false
            pd.targetId = nil
            showHomePage(playerId)
        end
    end
end

function handleCooldown(playerId)
    local pd = playerData[playerId]
    pd.stateTimer = pd.stateTimer - CONSTANTS.UI_UPDATE_INTERVAL
    
    if pd.stateTimer <= 0 then
        pd.state = "IDLE"
        showHomePage(playerId)
    end
end

-- UI Functions
function clearUI(playerId) tm.playerUI.ClearUI(playerId) end

function addLabel(playerId, key, text) tm.playerUI.AddUILabel(playerId, key, text) end

function addButton(playerId, key, text, callback) tm.playerUI.AddUIButton(playerId, key, text, callback) end

function setValue(playerId, key, text) tm.playerUI.SetUIValue(playerId, key, text) end

function showHomePage(playerId)
    clearUI(playerId)
    local pd = playerData[playerId]
    
    if pd.isBeingTargeted then addLabel(playerId, "warning", "Airstrike Incoming! Take Cover!") end
    if pd.state == "PRESTRIKE" then addLabel(playerId, "prestrike", "")
    elseif pd.state == "ACTIVE" then addLabel(playerId, "active", "Airstrike under way")
    elseif pd.state == "COOLDOWN" then addLabel(playerId, "cooldown", "") end
    
    if pd.pvpEnabled then
        addButton(playerId, "airstrike", "Call in an Airstrike!", showTargetSelect)
        addButton(playerId, "settings", "My Settings", showPlayerSettings)
        if playerId == 0 then -- Host only
            addButton(playerId, "serversettings", "Strike Settings", showServerSettings)
        end
    else
        addLabel(playerId, "info1", "PvP is OFF - you're safe from strikes")
        addButton(playerId, "settings", "My Settings", showPlayerSettings)
    end
end

function showTargetSelect(callback)
    local playerId = callback.playerId
    clearUI(playerId)
    addLabel(playerId, "select", "Select a Target")
    
    for _, player in ipairs(tm.players.CurrentPlayers()) do
        if playerData[player.playerId].pvpEnabled then
            addButton(playerId, "player_" .. player.playerId, 
                     tm.players.GetPlayerName(player.playerId), triggerAirstrike)
        end
    end
    addButton(playerId, "back", "<< Back", showHomePage)
end

function showPlayerSettings(callback) -- Simplified for brevity
    local playerId = callback.playerId
    clearUI(playerId)
    addLabel(playerId, "title", "My Settings")
    addButton(playerId, "pvp", "PvP (" .. (playerData[playerId].pvpEnabled and "on" or "off") .. ")", togglePVP)
    addButton(playerId, "fx", CONSTANTS.FX_TYPES[playerData[playerId].fxIndex], cycleExplosion)
    addButton(playerId, "back", "<< Back", showHomePage)
end

function showServerSettings(callback) -- Simplified for brevity
    local playerId = callback.playerId
    clearUI(playerId)
    addLabel(playerId, "title", "Server Settings")
    addButton(playerId, "help", "How to Use", showHelpPage)
    addButton(playerId, "cooldown", "Cooldown: " .. CONSTANTS.DEFAULT_COOLDOWN .. "s", cycleCooldown)
    -- Add other settings buttons...
    addButton(playerId, "back", "<< Back", showHomePage)
end

function showHelpPage(callback)
    local playerId = callback.playerId
    clearUI(playerId)
    addLabel(playerId, "title", "Settings Help")
    for _, text in ipairs(CONSTANTS.INFO_TEXT) do
        addLabel(playerId, "info_" .. _, text)
    end
    addButton(playerId, "back", "<< Back", showServerSettings)
end

-- Action Handlers
function triggerAirstrike(callback)
    local playerId = callback.playerId
    local targetId = tonumber(callback.id:match("player_(%d+)"))
    local pd = playerData[playerId]
    
    pd.targetId = targetId
    pd.state = "PRESTRIKE"
    pd.stateTimer = CONSTANTS.DEFAULT_STRIKE_DELAY
    playerData[targetId].isBeingTargeted = true
    setValue(targetId, "warning", "Airstrike Incoming! Take Cover!")
    showHomePage(playerId)
end

function togglePVP(callback)
    local playerId = callback.playerId
    playerData[playerId].pvpEnabled = not playerData[playerId].pvpEnabled
    showPlayerSettings(callback)
end

function cycleExplosion(callback)
    local playerId = callback.playerId
    local pd = playerData[playerId]
    pd.fxIndex = (pd.fxIndex % #CONSTANTS.FX_TYPES) + 1
    spawnExplosion(tm.players.GetPlayerTransform(playerId).GetPosition(), 
                  CONSTANTS.FX_TYPES[pd.fxIndex])
    showPlayerSettings(callback)
end

function cycleCooldown(callback) -- Simplified for brevity
    CONSTANTS.DEFAULT_COOLDOWN = (CONSTANTS.DEFAULT_COOLDOWN + 10) % 310
    setValue(callback.playerId, "cooldown", "Cooldown: " .. CONSTANTS.DEFAULT_COOLDOWN .. "s")
end

-- Utility Functions
function spawnExplosion(pos, model) return tm.physics.SpawnObject(pos, model) end

function getRandomVariance(radius)
    return tm.vector3.Create(
        math.random(-radius, radius),
        0,
        math.random(-radius, radius)
    )
end

function updateUI(playerId)
    local pd = playerData[playerId]
    if pd.state == "PRESTRIKE" then
        setValue(playerId, "prestrike", string.format("%.1f seconds to impact", pd.stateTimer))
    elseif pd.state == "COOLDOWN" then
        setValue(playerId, "cooldown", string.format("Cooldown: %.1f seconds", pd.stateTimer))
    end
    setValue(playerId, "time", string.format("Time: %.1f", pd.totalTime))
end
