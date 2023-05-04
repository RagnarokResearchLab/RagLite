local specFiles = {
	"Tests/FileFormats/RagnarokGRF.spec.lua",
	"Tests/WorldServer/C_ServerHealth.spec.lua",
	"Tests/WorldServer/WorldServer.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
