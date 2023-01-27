# Garrysmod Log Uploader Utility

This is a simple utility for content creators and server owners to upload their server logs to share with others.

This helps to reduce support time and allows for easier debugging of issues.

The Uploader script is hosted on github and is open source so you can see what it does and how it works. This also allows us to use a single command to run it.

## Usage

To use the uploader, simply run the following command in your server console:

`lua_run http.Fetch("https://raw.githubusercontent.com/JustPlayerDE/<todo>/master/uploader.lua", function(body) RunString(body) end)`

Because of how untrusted external Lua is, this script is hosted on github and is open source so you can see what it does and how it works before running it.

## How it works

The uploader will upload the following:

* The server log file (if it exists: `garrysmod/console.log`)
* Server Meta Data
  * Server OS
  * Server Name
  * Server IP and Port
  * Server Up Time
  * Server Gamemode (and where it derives from)
  * Server Map
  * Average Ping to players
  * Target and Average Tickrate
* Supported Addons (addons that register themselves with the uploader)
* Workshop Addons
* Filesystem Addons
* Modules (in the `lua/bin` folder)

The uploader will then return a URL that you can share with others to view the uploaded data.

Uploaded data is stored for 7 days and then fully removed.

Please note that everything is uploaded anonymously and no personal data is collected.

You may have to add `-condebug` to your launch options to get the server log file.

## Supported Addons

To Support your addon, you need to register it with the uploader. This is done by adding the following to your addon:

```lua
hook.Add("LogUploader.Register", "A hook name that should be unique to your addon", function(LogUploader)
    LogUploader.Register("Your Addon Name", {
        itemId = "Your Workshop or Gmodstore ID",
        version = "1.0.0",
        branch = "release", -- optional, defaults to "release" or "workshop" or "master" depending on the type
        author = "Your Name",
        type = "gmodstore",
        description = "A description of your addon, this can be multiple lines and will be displayed if the user clicks on your addon on the log viewer",
    })
end)
```

The `type` can be one of the following:

* `gmodstore` - Gmodstore Addons
* `git` - Git based Addons
* `workshop` - Workshop Addons which are supported
  * `workshop_mounted` - Mounted Unsupported Workshop Addons
  * `workshop_unmounted` - Unmounted Unsupported Workshop Addons
* `filesystem` - Filesystem Addons
* `module` - Modules (in the `lua/bin` folder)
