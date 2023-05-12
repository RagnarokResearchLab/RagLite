package.path = "?.lua"

local AssetServer = require("Core.AssetServer")
local RealmServer = require("Core.RealmServer")
local WorldServer = require("Core.WorldServer")

AssetServer:Start("data.grf")
RealmServer:Start()
WorldServer:Start()
