package.path = "?.lua"

local specFiles = {
	"Tests/DB/validate-creature-spawns.lua",
	"Tests/DB/validate-map-database.lua",
}

local numFailedTests = C_Runtime.RunBasicTests(specFiles)

os.exit(numFailedTests)
