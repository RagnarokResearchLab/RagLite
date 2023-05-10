package.path = "?.lua"

local specFiles = {
	"Tests/DB/validate-creature-spawns.lua",
	"Tests/RealmServer/serves-realm-list.lua",
}

local numFailedTests = C_Runtime.RunBasicTests(specFiles)

os.exit(numFailedTests)
