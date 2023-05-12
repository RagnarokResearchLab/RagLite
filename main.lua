package.path = "?.lua"

local AssetServer = require("Core.AssetServer")
local RealmServer = require("Core.RealmServer")
local WebClient = require("Core.WebClient")
local WorldServer = require("Core.WorldServer")

AssetServer:Start("data.grf")
RealmServer:Start()
WebClient:Start()
WorldServer:Start()
