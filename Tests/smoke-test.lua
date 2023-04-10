local specFiles = {
	"Tests/DB/validate-creature-spawns.lua",
}

local numFailedTests = C_Runtime.RunBasicTests(specFiles)

os.exit(numFailedTests)
