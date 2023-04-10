local specFiles = {
	"Tests/placeholder-test.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
