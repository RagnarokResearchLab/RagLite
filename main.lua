package.path = "?.lua"

local AssetServer = require("Core.AssetServer")
local WebClient = require("Core.WebClient")
local WorldServer = require("Core.WorldServer")

AssetServer:Start("data.grf")
WebClient:Start()
WorldServer:Start()
