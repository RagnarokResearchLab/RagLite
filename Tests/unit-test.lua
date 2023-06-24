package.path = "?.lua"

local specFiles = {
	"Tests/FileFormats/RagnarokGRF.spec.lua",
	"Tests/AssetServer/AssetServer.spec.lua",
	"Tests/NativeClient/NativeClient.spec.lua",
	"Tests/NativeClient/Renderer.spec.lua",
	"Tests/WorldServer/C_ServerHealth.spec.lua",
	"Tests/WorldServer/WorldServer.spec.lua",
	"Tests/Tools/RagnarokTools.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
