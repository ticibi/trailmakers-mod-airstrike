-- Airstrike!
-- by dinoman 2021

local playerDataTable = {}
local globalTimer = 0
local localTimer = 0
local impactCount = 10
local cooldown = 30
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

-------------------- Begin --------------------

function addPlayerData(playerId)
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
    }
end

function onPlayerJoined(player)
    tm.os.Log(tm.players.GetPlayerName(player.playerId) .. " joined the server")
    addPlayerData(player.playerId)
    initializeUI_AndKeybinds(player.playerId)
    loadCustomResources()
end

function onPlayerLeft(player)
    --tm.os.Log(tm.players.GetPlayerName(player.playerId) .. " left the server")
end

function initializeUI_AndKeybinds(playerId)
    homePage(playerId)
    --tm.input.RegisterFunctionToKeyDownCallback(playerId, "" ,"")
    --tm.input.RegisterFunctionToKeyUpCallback(playerId, "", "")
end

function loadCustomResources()
    --tm.physics.AddMesh("", "")
    --tm.physics.AddTexture("", "")
end

tm.players.OnPlayerJoined.add(onPlayerJoined)
tm.players.OnPlayerLeft.add(onPlayerLeft)

-------------------- Game logic --------------------

function update()
    local playerList = tm.players.CurrentPlayers()
    for k, player in pairs(playerList) do
        local playerData = playerDataTable[player.playerId]

        if localTimer > 10 then
            if playerData.prestrike then
                if playerData.prestrikeCountdown > 0 then
                    tm.playerUI.SetUIValue(player.playerId, "prestrike", "" .. playerData.prestrikeCountdown .. " seconds to impact")
                    playerData.prestrikeCountdown = playerData.prestrikeCountdown - 1
                    localTimer = 0
                else
                    playerData.prestrike = false
                    playerData.strikeActive = true
                    playerData.prestrikeCountdown = strikeDelay
                    homePage(player.playerId)
                end
            end

            if playerData.strikeActive then
                if playerData.strikeTimer > math.random(1, strikeInterval) then --customize interval
                    if playerData.impactCount < impactCount then
                        local targetPos = tm.players.GetPlayerTransform(playerData.target).GetPosition()
                        local variance = varianceVector(strikeRadius) --customize radius
                        tm.physics.SpawnObject(tm.vector3.op_Addition(targetPos, variance), "PFB_Explosion_Large")
                        playerData.impactCount = playerData.impactCount + 1
                        playerData.strikeTimer = 0
                    else
                        playerData.strikeActive = false
                        playerData.isOnCooldown = true
                        playerData.impactCount = 0
                        playerData.strikeTimer = 0
                        playerDataTable[playerData.target].isBeingTargeted = false
                        tm.playerUI.SetUIValue(playerData.target, "warning", "")
                        homePage(player.playerId)
                    end
                end
            end

            if playerData.isOnCooldown then
                if playerData.cooldownTimer > 0 then
                    tm.playerUI.SetUIValue(player.playerId, "cooldown", "Cooldown: " .. playerData.cooldownTimer .. " seconds")
                    playerData.cooldownTimer = playerData.cooldownTimer - 1
                    localTimer = 0
                else
                    playerData.isOnCooldown = false
                    homePage(player.playerId)
                end
            end
        end

        localTimer = localTimer + 1
        globalTimer = globalTimer + 1
        playerData.strikeTimer = playerData.strikeTimer + 1
        tm.playerUI.SetUIValue(player.playerId, "globaltime", "time: " .. globalTimer/10)
    end
end

function startAirstrike(callbackData)
    local playerData = playerDataTable[callbackData.playerId]
    local targetId = tonumber(string.sub(callbackData.id, 8))
    playerData.target = targetId
    playerDataTable[targetId].isBeingTargeted = true
    tm.playerUI.SetUIValue(targetId, "warning", "Airstrike Incoming! Take Cover!")
    playerData.prestrike = true
    playerData.cooldownTimer = cooldown
    playerData.prestrikeCountdown = strikeDelay
    homePage(callbackData.playerId)
end

-------------------- UI helpers --------------------

function title(playerId, titleText)
    tm.playerUI.AddUILabel(playerId, "title", titleText)
end

function divider(playerId)
    tm.playerUI.AddUILabel(playerId, "divider", "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬") 
end

function gotoButton(playerId, buttonText, page)
    tm.playerUI.AddUIButton(playerId, "goto", buttonText, page)
end

function returnHome(callbackData)
    homePage(callbackData.playerId)
end

-------------------- UI Pages --------------------

function homePage(playerId)
    local playerData = playerDataTable[playerId]
    tm.playerUI.ClearUI(playerId)
    if playerData.isBeingTargeted then
        tm.playerUI.AddUILabel(playerId, "warning", "Airstrike Incoming! Take Cover!")
    end
    if playerData.prestrike then
        tm.playerUI.AddUILabel(playerId, "prestrike", "")
    elseif playerData.strikeActive then
        tm.playerUI.AddUILabel(playerId, "active", "Airstrike under way")
    elseif playerData.isOnCooldown then
        tm.playerUI.AddUILabel(playerId, "cooldown", "")
    elseif playerData.pvpEnabled then
        tm.playerUI.AddUIButton(playerId, "airstrike", "Call in an Airstrike", targetingPage)
        tm.playerUI.AddUIButton(playerId, "My Settings", "My Settings", playerSettingsPage)
        if playerId == 0 then
            tm.playerUI.AddUIButton(playerId, "serversettings", "Server Settings", serverSettingsPage)
        end
    else
        tm.playerUI.AddUILabel(playerId, "info1", "PvP is turned OFF and will stop")
        tm.playerUI.AddUILabel(playerId, "info2", "other players from targeting you.")
        tm.playerUI.AddUILabel(playerId, "info3", "If you want to call in airstrikes,")
        tm.playerUI.AddUILabel(playerId, "info4", "turn PvP ON in My Settings")
        tm.playerUI.AddUIButton(playerId, "My Settings", "My Settings", playerSettingsPage)
    end
    --tm.playerUI.AddUILabel(playerId, "globaltime", "global time: " .. globalTimer) 
end

function targetingPage(callbackData)
    local playerId = callbackData.playerId
    local playerData = playerDataTable[playerId]
    tm.playerUI.ClearUI(playerId)
    title(playerId, "Select a target")
    for _, player in pairs(tm.players.CurrentPlayers()) do
        local id = player.playerId
        if playerDataTable[id].pvpEnabled then
            tm.playerUI.AddUIButton(playerId, "player_" .. id, tm.players.GetPlayerName(id), startAirstrike)
        end
    end
    gotoButton(playerId, "<< back", returnHome)
end

function serverSettingsPage(callbackData)
    local playerId = callbackData.playerId
    tm.playerUI.ClearUI(playerId)
    title(playerId, "Server Settings")
    tm.playerUI.AddUIButton(playerId, "info", "Help", infoPage)
    tm.playerUI.AddUIButton(playerId, "settings1", "cooldown: " .. cooldown .. " seconds", cycleCooldown)
    tm.playerUI.AddUIButton(playerId, "settings2", "impact count: " .. impactCount, cycleImpactCount)
    tm.playerUI.AddUIButton(playerId, "settings3", "strike radius: " .. strikeRadius, cycleStrikeRadius)
    tm.playerUI.AddUIButton(playerId, "settings4", "strike interval: " .. strikeInterval, cycleStrikeInterval)
    tm.playerUI.AddUIButton(playerId, "settings5", "strike delay: " .. strikeDelay, cycleStrikeDelay)
    gotoButton(playerId, "<< back", returnHome)
end

function infoPage(callbackData)
    local playerId = callbackData.playerId
    tm.playerUI.ClearUI(playerId)
    title(playerId, "Settings Help")
    tm.playerUI.AddUILabel(playerId, "help1", " ---- cooldown ----")
    tm.playerUI.AddUILabel(playerId, "help1.1", "wait time to call in another strike")
    divider(playerId)
    tm.playerUI.AddUILabel(playerId, "help2", " ---- impact count ----")
    tm.playerUI.AddUILabel(playerId, "help2.1", "number of explosions in a strike")
    divider(playerId)
    tm.playerUI.AddUILabel(playerId, "help3", " ---- strike radius ---- ")
    tm.playerUI.AddUILabel(playerId, "help3.1", "distance around the target in")
    tm.playerUI.AddUILabel(playerId, "help3.2", "which impacts will strike")
    tm.playerUI.AddUILabel(playerId, "help3.3", "higher value is farther from target")
    tm.playerUI.AddUILabel(playerId, "help3.4", "and less accurate")
    tm.playerUI.AddUILabel(playerId, "help3.5", "lower value is closer to target")
    tm.playerUI.AddUILabel(playerId, "help3.6", "and more accurate")
    divider(playerId)
    tm.playerUI.AddUILabel(playerId, "help4", " ---- strike interval ---- ")
    tm.playerUI.AddUILabel(playerId, "help4.1", "time between impacts")
    tm.playerUI.AddUILabel(playerId, "help4.2", "lower value is less time")
    tm.playerUI.AddUILabel(playerId, "help4.3", "higher value is more time")
    divider(playerId)
    tm.playerUI.AddUILabel(playerId, "help5", " ---- strike delay ---- ")
    tm.playerUI.AddUILabel(playerId, "help5.1", "time (seconds) between calling in a")
    tm.playerUI.AddUILabel(playerId, "help5.2", "strike and strike execution")
    gotoButton(playerId, "<< back", serverSettingsPage)
end

function cycleCooldown(callbackData)
    if cooldown >= 120 then
        cooldown = cooldown + 20
    else
        cooldown = cooldown + 10
    end
    if cooldown > 300 then
        cooldown = 10
    end
    tm.playerUI.SetUIValue(callbackData.playerId, "settings1", "cooldown: " .. cooldown .. " seconds")
end

function cycleImpactCount(callbackData)
    impactCount = impactCount + 5
    if impactCount > 50 then
        impactCount = 5
    end
    tm.playerUI.SetUIValue(callbackData.playerId, "settings2", "impact count: " .. impactCount)
end

function cycleStrikeRadius(callbackData)
    strikeRadius = strikeRadius + 10
    if strikeRadius > 100 then
        strikeRadius = 10
    end
    tm.playerUI.SetUIValue(callbackData.playerId, "settings3", "strike radius: " .. strikeRadius)
end

function cycleStrikeInterval(callbackData)
    strikeInterval = strikeInterval + 5
    if strikeInterval > 50 then
        strikeInterval = 5
    end
    tm.playerUI.SetUIValue(callbackData.playerId, "settings4", "strike interval: " .. strikeInterval)
end

function cycleStrikeDelay(callbackData)
    if strikeDelay < 5 then
        strikeDelay = strikeDelay + 1
    else
        strikeDelay = strikeDelay + 5
    end
    if strikeDelay > 30 then
        strikeDelay = 1
    end
    tm.playerUI.SetUIValue(callbackData.playerId, "settings5", "strike delay: " .. strikeDelay)
end

function playerSettingsPage(callbackData)
    local playerId = callbackData.playerId
    tm.playerUI.ClearUI(playerId)
    title(playerId, "My Settings")
    if playerDataTable[playerId].pvpEnabled then
        tm.playerUI.AddUIButton(playerId, "pvp", "PvP: (on)", togglePvp)
    else
        tm.playerUI.AddUIButton(playerId, "pvp", "PvP: (off)", togglePvp)
    end
    --if playerDataTable[playerId].targetSelf then
    --    tm.playerUI.AddUIButton(playerId, "targetself", "Target Self: (on)", toggleTargetSelf)
    --else
    --    tm.playerUI.AddUIButton(playerId, "targetself", "Target Self: (off)", toggleTargetSelf)
    --end
    gotoButton(playerId, "<< back", returnHome)
end

function toggleTargetSelf(callbackData)
    local playerId = callbackData.playerId
    playerDataTable[playerId].targetSelf = not playerDataTable[playerId].targetSelf
    if playerDataTable[playerId].targetSelf then
        tm.playerUI.SetUIValue(playerId, "targetself", "Target Self: (on)")
    else
        tm.playerUI.SetUIValue(playerId, "targetself", "Target Self: (off)")
    end
end

function togglePvp(callbackData)
    local playerId = callbackData.playerId
    playerDataTable[playerId].pvpEnabled = not playerDataTable[playerId].pvpEnabled
    if playerDataTable[playerId].pvpEnabled then
        tm.playerUI.SetUIValue(playerId, "pvp", "PvP: (on)")
    else
        tm.playerUI.SetUIValue(playerId, "pvp", "PvP: (off)")
    end
end

-------------------- Utils --------------------

function randomChoice(table)
    return table[math.random(#table)]
end

function varianceVector(limit)
    return tm.vector3.Create(
        math.random(-limit, limit), 
        0, 
        math.random(-limit, limit)
    )
end
