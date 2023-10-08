local RagnarokACT = require("Core.FileFormats.RagnarokACT")

local inputFiles = {
	"v0200.act",
	"v0201.act",
	"v0203.act",
	"v0204.act",
	"v0205.act",
}

for index, inputFile in ipairs(inputFiles) do
	local inputFilePath = path.join("Tests", "Fixtures", inputFile)
	local outputFilePath = path.join("Tests", "Fixtures", "Snapshots", inputFile .. ".json")
	printf("Updating snapshot: %s ~> %s", inputFilePath, outputFilePath)
	local act = RagnarokACT()
	act:DecodeFileContents(C_FileSystem.ReadFile(inputFilePath))
	C_FileSystem.WriteFile(outputFilePath, act:ToJSON())
end
