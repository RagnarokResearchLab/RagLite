local specFiles = {
	"Tests/placeholder-test.lua",
}

local numFailedTests = C_Runtime.RunBasicTests(specFiles)

os.exit(numFailedTests)
