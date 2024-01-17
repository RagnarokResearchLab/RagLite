package.path = "?.lua"

local specFiles = {
	"Tests/WebGPU/render-3d-cube.lua",
}

local numFailedSections = C_Runtime.RunBasicTests(#arg > 0 and arg or specFiles)

os.exit(numFailedSections)
