-- Airstrike! Mod for Trailmakers, ticibi 2022
-- name: Airstrike!
-- author: Thomas Bresee
-- description: 


local playerDataTable = {}
local impactCount = 10
local cooldown = 0
local strikeInterval = 25
local strikeRadius = 50
local strikeDelay = 5
local FX = {
    "PFB_PoisonCloud_Explosion",
    "PFB_Explosion_Large",
    "PFB_Explosion_Medium",
    "PFB_Explosion_Micro",
    "PFB_Explosion_SeatDeath",
    "PFB_Explosion_Small",
    "PFB_Explosion_XL",
}
local infoPageText = {
    "---- cooldown ----",
    "(in seconds)",
    "time to wait after calling in a strike",
    " ",
    "---- impact count ----",
    "number of explosions per strike",
    " ",
    "---- strike radius ----",
    "distance around target in which",
    "explosions will occur:",
    "higher value = farther from target",
    "and less accurate",
    "lower value = closer to target",
    "and more accurate",
    " ",
    "---- strike interval ----",
    "(in milliseconds)",
    "time in between consecutive explosions",
    "higher value = more wait time",
    "lower value = less wait time",
    " ",
    "---- strike delay ----",
    "(in seconds)",
    "wait time in between calling in an",
    "airstrike and strike execution",
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function AddPlayerData(playerId)
    playerDataTable[playerId] = {
        pvpEnabled = true,
        targetSelf = true,
        isBeingTargeted = false,
        prestrike = false,
        strikeActive = false,
        isOnCooldown = false,
        impactCount = 0,
        strikeTimer = 0,
        prestrikeCountdown = strikeDelay,
        cooldownTimer = cooldown,
        target = nil,
        fxIndex = 1,
        localTimer = 0,
        globalTimer = 0,
    }
end

function onPlayerJoined(player)
    AddPlayerData(player.playerId)
    HomePage(player.playerId)
end

tm.players.OnPlayerJoined.add(onPlayerJoined)


function update()
    local players = tm.players.CurrentPlayers()
    for i, player in pairs(players) do
        local playerId = player.playerId
        local playerData = playerDataTable[playerId]
        if playerData.localTimer > 10 then
            if playerData.prestrike then
                Prestrike(playerId)
            end
            if playerData.strikeActive then
                Airstrike(playerId)
            end
            if playerData.isOnCooldown then
                Cooldown(playerId)
            end
        end
        UpdateTimers(playerId)
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function Prestrike(playerId)
    local playerData = playerDataTable[playerId]
    if playerData.prestrikeCountdown > 0 then
        SetValue(playerId, "prestrike", "" .. playerData.prestrikeCountdown .. " seconds to impact")
        playerData.prestrikeCountdown = playerData.prestrikeCountdown - 1
        playerData.localTimer = 0
    else
        playerData.prestrike = false
        playerData.strikeActive = true
        playerData.prestrikeCountdown = strikeDelay
        HomePage(playerId)
    end
end

function Airstrike(playerId)
    local playerData = playerDataTable[playerId]
    if playerData.strikeTimer > math.random(1, strikeInterval) then
        if playerData.impactCount < impactCount then
            local targetPos = tm.players.GetPlayerTransform(playerData.target).GetPosition()
            local variance = VarianceVector(strikeRadius)
            local spawnPos = tm.vector3.op_Addition(targetPos, variance)
            Spawn(spawnPos, FX[playerData.fxIndex])
            playerData.impactCount = playerData.impactCount + 1
            playerData.strikeTimer = 0
        else
            playerData.strikeActive = false
            playerData.isOnCooldown = true
            playerData.impactCount = 0
            playerData.strikeTimer = 0
            playerDataTable[playerData.target].isBeingTargeted = false
            SetValue(playerData.target, "warning", "")
            HomePage(playerId)
        end
    end
end

function Cooldown(playerId)
    local playerData = playerDataTable[playerId]
    if playerData.cooldownTimer > 0 then
        SetValue(playerId, "cooldown", "Cooldown: " .. playerData.cooldownTimer .. " seconds")
        playerData.cooldownTimer = playerData.cooldownTimer - 1
        playerData.localTimer = 0
    else
        playerData.isOnCooldown = false
        HomePage(playerId)
    end
end

function UpdateTimers(playerId)
    local playerData = playerDataTable[playerId]
    playerData.localTimer = playerData.localTimer + 1
    playerData.globalTimer = playerData.globalTimer + 1
    playerData.strikeTimer = playerData.strikeTimer + 1
    SetValue(playerId, "globaltime", "time: " .. playerData.globalTimer/10)
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function Clear(playerId)
    tm.playerUI.ClearUI(playerId)
end

function Divider(playerId)
    tm.playerUI.AddUILabel(playerId, "divider", "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬") 
end

function SetValue(playerId, key, text)
    tm.playerUI.SetUIValue(playerId, key, text)
end

function Label(playerId, key, text)
    tm.playerUI.AddUILabel(playerId, key, text)
end

function Button(playerId, key, text, func)
    tm.playerUI.AddUIButton(playerId, key, text, func)
end

function HomePage(playerId)
    if type(playerId) ~= "number" then
        playerId = playerId.playerId
    end
    local playerData = playerDataTable[playerId]
    Clear(playerId)
    if playerData.isBeingTargeted then
        Label(playerId, "warning", "Airstrike Incoming! Take Cover!")
    end
    if playerData.prestrike then
        Label(playerId, "prestrike", "")
    elseif playerData.strikeActive then
        Label(playerId, "active", "Airstrike under way")
    elseif playerData.isOnCooldown then
        Label(playerId, "cooldown", "")
    elseif playerData.pvpEnabled then
        Button(playerId, "airstrike", "call in an Airstrike!", TargetSelectPage)
        Button(playerId, "My Settings", "my settings", PlayerSettingsPage)
        if playerId == 0 then -- player is the Host
            Button(playerId, "serversettings", "strike settings", ServerSettingsPage)
        end
    else
        Label(playerId, "info1", "PvP is turned OFF and will stop")
        Label(playerId, "info2", "other players from targeting you.")
        Label(playerId, "info3", "If you want to call in airstrikes,")
        Label(playerId, "info4", "turn PvP ON in My Settings")
        Button(playerId, "my settings", "my settings", PlayerSettingsPage)
    end
end

function TargetSelectPage(callback)
    local playerId = callback.playerId
    Clear(playerId)
    Label(playerId, "select target", "select a target")
    local players = tm.players.CurrentPlayers()
    for i, player in ipairs(players) do
        local id = player.playerId
        if playerDataTable[id].pvpEnabled then
            local playerName = tm.players.GetPlayerName(id)
            Button(playerId, "player_" .. id, playerName, OnTriggerAirstrike)
        end
    end
    Button(playerId, "back", "<< back", HomePage)
end

function HowToPage(callback)
    local playerId = callback.playerId
    Clear(playerId)
    Label(playerId, "settings help", "Settings Help")
    for _, text in ipairs(infoPageText) do
        Label(playerId, "help", text)
    end
    Button(playerId, "back", "<< back", ServerSettingsPage)
end

function PlayerSettingsPage(callback)
    local playerId = callback.playerId
    Clear(playerId)
    Label(playerId, "my settings", "my settings")
    if playerDataTable[playerId].pvpEnabled then
        Button(playerId, "pvp", "pvp (on)", TogglePVP)
    else
        Button(playerId, "pvp", "pvp (off)", TogglePVP)
    end
    Button(playerId, "explosion model", FX[playerDataTable[playerId].fxIndex], CycleExplosion)
    Button(playerId, "back", "<< back", HomePage)
end

function ServerSettingsPage(callback)
    local playerId = callback.playerId
    Clear(playerId)
    Label(playerId, "server settings", "server settings")
    Button(playerId, "help", "how to use", HowToPage)
    Button(playerId, "settings1", "cooldown: " .. cooldown .. "s", CycleCooldown)
    Button(playerId, "settings2", "impact count: " .. impactCount, CycleImpactCount)
    Button(playerId, "settings3", "strike radius: " .. strikeRadius .. "m", CycleStrikeRadius)
    Button(playerId, "settings4", "strike interval: " .. strikeInterval .. "ms", CycleStrikeInterval)
    Button(playerId, "settings5", "strike delay: " .. strikeDelay .. "s", CycleStrikeDelay)
    Button(playerId, "back", "<< back", HomePage)
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function OnTriggerAirstrike(callback)
    local playerData = playerDataTable[callback.playerId]
    local targetId = tonumber(string.sub(callback.id, 8))
    playerData.target = targetId
    playerDataTable[targetId].isBeingTargeted = true
    SetValue(targetId, "warning", "Airstrike Incoming! Take Cover!")
    playerData.prestrike = true
    playerData.cooldownTimer = cooldown
    playerData.prestrikeCountdown = strikeDelay
    HomePage(callback.playerId)
end

function CycleCooldown(callback)
    if cooldown >= 120 then
        cooldown = cooldown + 20
    else
        cooldown = cooldown + 10
    end
    if cooldown > 300 then
        cooldown = 0
    end
    SetValue(callback.playerId, "settings1", "cooldown: " .. cooldown .. "s")
end

function CycleImpactCount(callback)
    impactCount = impactCount + 5
    if impactCount > 50 then
        impactCount = 5
    end
    SetValue(callback.playerId, "settings2", "impact count: " .. impactCount)
end

function CycleStrikeRadius(callback)
    strikeRadius = strikeRadius + 10
    if strikeRadius > 100 then
        strikeRadius = 10
    end
    SetValue(callback.playerId, "settings3", "strike radius: " .. strikeRadius .. "m")
end

function CycleStrikeInterval(callback)
    strikeInterval = strikeInterval + 5
    if strikeInterval > 50 then
        strikeInterval = 5
    end
    SetValue(callback.playerId, "settings4", "strike interval: " .. strikeInterval .. "ms")
end

function CycleStrikeDelay(callback)
    if strikeDelay < 5 then
        strikeDelay = strikeDelay + 1
    else
        strikeDelay = strikeDelay + 5
    end
    if strikeDelay > 30 then
        strikeDelay = 1
    end
    SetValue(callback.playerId, "settings5", "strike delay: " .. strikeDelay .. "s")
end

function CycleExplosion(callback)
    local playerId = callback.playerId
    if playerDataTable[playerId].fxIndex < #FX then
        playerDataTable[playerId].fxIndex = playerDataTable[playerId].fxIndex + 1
    else
        playerDataTable[playerId].fxIndex = 1
    end
    local playerPos = GetPlayerPos(playerId)
    Spawn(playerPos, FX[playerDataTable[playerId].fxIndex])
    SetValue(playerId, "explosion model", FX[playerDataTable[playerId].fxIndex])
end

function TogglePVP(callback)
    local playerId = callback.playerId
    playerDataTable[playerId].pvpEnabled = not playerDataTable[playerId].pvpEnabled
    if playerDataTable[playerId].pvpEnabled then
        SetValue(playerId, "pvp", "PvP (on)")
    else
        SetValue(playerId, "pvp", "PvP (off)")
    end
end

function Spawn(pos, model)
    return tm.physics.SpawnObject(pos, model)
end

function GetPlayerPos(playerId)
    return tm.players.GetPlayerTransform(playerId).GetPosition()
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function VarianceVector(limit)
    return tm.vector3.Create(
        math.random(-limit, limit), 
        0, 
        math.random(-limit, limit)
    )
end
