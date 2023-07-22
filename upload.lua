--[[
    Log Uploader
    This file will upload the log file of the server it is running on to logs.justplayer.de
    It will also send the server name and the server ip to the server.

    The Logs will be available at http://logs.justplayer.de and will be deleted after 7 days.
    Data Sent to the server:
        - Server Name
        - Server IP
        - Player Count
        - Average Ping of all players
        - Tickrate of the server
        - Average Tickrate of the server of the last 60 seconds
        - Console.log (if -condebug is set as a launch parameter, i recommend also setting -conclearlog)
        - Server Addons (Workshop, AND FileSystem directories in /addons/)
]]
local gamemode = GM or GAMEMODE

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "+")

    return str
end

-- Nice looking log
local function log(...)
    print("[Log Uploader] ", string.format(...))
end

local function logDebug(...)
    if not GetConVar("developer"):GetBool() then return end
    print("[Log Uploader Debug] ", string.format(...))
end

if player.GetCount() < 1 and not GetConVar("sv_hibernate_think"):GetBool() then
    -- Spawn bot to force disable hibernation
    log("Hibernation is enabled, spawning bot to disable hibernation")
    game.ConsoleCommand("bot\n")
end

local function getAveragePing()
    local sum = 0

    for k, v in pairs(player.GetAll()) do
        sum = sum + v:Ping()
    end

    if #player.GetHumans() == 0 then return 0 end

    return math.Round((sum / #player.GetHumans()) * 100) / 100
end

local tickStartTime = SysTime()
local tickStart = engine.TickCount()

local function getAverageTickrate()
    local ticks = engine.TickCount() - tickStart
    local ticksPerSecond = ticks / (SysTime() - tickStartTime)

    return math.floor(ticksPerSecond * 100) / 100
end

-- get supported server addons
local LogUploader = {}
LogUploader.Addons = {}

local typeDefaultBranch = {
    ["gmodstore"] = "release",
    ["workshop"] = "workshop",
    ["workshop_mounted"] = "workshop",
    ["workshop_unmounted"] = "workshop",
    ["git"] = "master"
}

LogUploader.Register = function(name, data, no_log)
    local addonData = {
        name = name,
        itemId = (data.itemId and data.itemId) or nil,
        version = data.version or "[unknown]",
        author = data.author or "[unknown]",
        type = data.type or "[unknown]",
        branch = (data.branch and data.branch) or (data.type and typeDefaultBranch[data.type] or "[unknown]")
    }

    if not no_log then
        logDebug("Found Supported addon: %s, version: %s, branch: %s, type: %s", addonData.name, addonData.version, addonData.branch, addonData.type)
    end

    table.insert(LogUploader.Addons, addonData)
end

hook.Run("LogUploader.Register", LogUploader)
-- add workshop addons 
local workshopAddons = engine.GetAddons()

for i = 1, #workshopAddons do
    local addon = workshopAddons[i]

    -- check if addon is not already added
    for i = 1, #LogUploader.Addons do
        if tonumber(LogUploader.Addons[i].itemId) == tonumber(addon.wsid) then
            logDebug("Found Supported Workshop addon: %i (%s)", addon.wsid, LogUploader.Addons[i].name)
            continue
        end
    end

    --logDebug("Found Workshop addon: %i (%s)", addon.wsid, addon.title)
    LogUploader.Register(addon.title, {
        itemId = addon.wsid, -- Workshop only
        version = addon.updated,
        type = "workshop_" .. (addon.mounted and "mounted" or "unmounted")
    }, true)
end

-- add filesystem addons in /addons/
local _, fileSystemAddonDirectories = file.Find("addons/*", "GAME")

-- check gma first
for name, addon in pairs(fileSystemAddonDirectories) do
    -- check if addon contains "lua" folder
    if not file.Exists("addons/" .. addon .. "/lua", "GAME") then continue end
    local addoninfo = {}

    -- addon.txt is not required, but if it exists, we can get the name, author and version from it
    if file.Exists("addons/" .. addon .. "/addon.txt", "GAME") then
        -- i decided to not use util.KeyValuesToTable because it tries to convert values to numbers if possible
        -- this breaks stuff like 3.2 as it has rounding errors when converting to a number
        local addontxt = file.Open("addons/" .. addon .. "/addon.txt", "r", "GAME")
        local addonData = {}

        local i = 0 -- just to be safe, dont want to get stuck in an infinite loop
        while true do
            if i > 100 then break end -- just to be safe
            i = i + 1
            local line = addontxt:ReadLine()
            if not line then break end

            -- check if line is a comment
            if string.StartWith( string.Trim(line), "#") then continue end
            if string.StartWith( string.Trim(line), "//") then continue end

            -- get key and value
            local key, value = string.match(line, "\"([^\"]+)\"%s+\"([^\"]+)\"")
            if not key or not value then continue end
            -- add to table
            addonData[key] = value
        end

        addontxt:Close()
        addoninfo = {
            name = addonData.name,
            author = addonData.author_name,
            version = addonData.version
        }
    end

    -- get info from git if it exists
    -- This will overwrite the informations we got from addon.txt, but git should be more accurate
    if file.Exists("addons/" .. addon .. "/.git/HEAD", "GAME") then
        local gitHead = file.Open("addons/" .. addon .. "/.git/HEAD", "r", "GAME")
        local branch = gitHead:ReadLine()
        gitHead:Close()

        if string.StartWith(branch, "ref: refs/heads/") then
            addoninfo.branch = string.sub(branch, 17):Trim()
            addoninfo.type = "git"
        end

        if addoninfo.branch and file.Exists("addons/" .. addon .. "/.git/refs/heads/" .. addoninfo.branch, "GAME") then
            local gitHead = file.Open("addons/" .. addon .. "/.git/refs/heads/" .. addoninfo.branch, "r", "GAME")
            addoninfo.version = gitHead:ReadLine():Trim()
            gitHead:Close()
        end
    end

    if addoninfo.name then
        logDebug("Found FileSystem addon: %s (%s)", addoninfo.name or addon, addon)
    else
        logDebug("Found FileSystem addon: %s", addon)
    end

    LogUploader.Register(addoninfo.name or addon, {
        type =  addoninfo.type or "filesystem",
        author = addoninfo.author,
        version = addoninfo.version,
        branch = addoninfo.branch
    }, true)
end

-- check lua modules
local moduleAddons, _ = file.Find("lua/bin/*", "GAME")

for name, addon in pairs(moduleAddons) do
    -- check if file is a module (ends with .dll or .so)
    if not string.EndsWith(addon, ".dll") and not string.EndsWith(addon, ".so") then continue end
    logDebug("Found Module addon: %s", addon)

    LogUploader.Register(addon, {
        type = "module"
    }, true)
end

-- generate output
function LogUploader.GenerateOutput()
    -- copyied from https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/extensions/util.lua#L369-L397
    local serverOs = ({"osx64", "osx", "linux64", "linux", "win64", "win32"})[(system.IsWindows() and 4 or 0) + (system.IsLinux() and 2 or 0) + (jit.arch == "x86" and 1 or 0) + 1]

    local gamemode = gamemode or GM or gmod.GetGamemode()

    local output = {
        os = serverOs,
        ip = game.GetIPAddress(),
        name = GetConVar("hostname"):GetString(),
        gamemode = gamemode.Name,
        gamemode_directory = engine.ActiveGamemode(),
        gamemode_base = gamemode.BaseClass.Name or "base",
        map = game.GetMap(),
        uptime = SysTime(),
        players = player.GetCount(),
        average_ping = getAveragePing(),
        tickrate = 1 / engine.TickInterval(),
        average_tickrate = getAverageTickrate(),
        addons_found = #LogUploader.Addons,
        addons = LogUploader.Addons
    }

    return output
end

log("Waiting 5 seconds...")
timer.Simple(5, function()
    log("Fetching server info...")
    local output = LogUploader.GenerateOutput()
    local json = util.TableToJSON(output)

    log("Uploading server info...")

    -- send json blob to server
    http.Post("https://logs.justplayer.de", {
        json = urlencode(json)
    }, function(body, len, headers, code)
        if code == 200 then
            log("Successfully uploaded server info to LogUploader!")
            log("URL (may contain sensitive info, do not share with anyone that could abuse it): %s", body)
        else
            log("Failed to upload server info to LogUploader! (Code: %i)", code)
        end
    end, function(err)
        log("Failed to upload server info to LogUploader! (Error: %s)", err)
    end)
end)
