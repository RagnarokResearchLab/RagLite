package.path = "?.lua"

local specFiles = {
	"Tests/AssetServer/404-not-found.lua",
	"Tests/AssetServer/serves-grf-contents.lua",
	"Tests/AssetServer/serves-grf-index.lua",
	"Tests/AssetServer/serves-file-contents.lua",
	"Tests/DB/validate-creature-spawns.lua",
}

local numFailedTests = C_Runtime.RunBasicTests(specFiles)

os.exit(numFailedTests)
