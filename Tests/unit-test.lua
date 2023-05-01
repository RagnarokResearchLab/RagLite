local specFiles = {
	"Tests/WorldServer/C_ServerHealth.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
