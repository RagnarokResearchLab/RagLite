package.path = "?.lua"

local specFiles = {
	"Tests/FileFormats/RagnarokGND.spec.lua",
	"Tests/FileFormats/RagnarokGRF.spec.lua",
	"Tests/AssetServer/AssetServer.spec.lua",
	"Tests/WorldServer/C_ServerHealth.spec.lua",
	"Tests/WorldServer/WorldServer.spec.lua",
	"Tests/Tools/RagnarokTools.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
