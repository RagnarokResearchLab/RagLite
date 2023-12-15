package.path = "?.lua"

local AssetServer = require("Core.AssetServer")
local WorldServer = require("Core.WorldServer")

AssetServer:Start("data.grf")
WorldServer:Start()
