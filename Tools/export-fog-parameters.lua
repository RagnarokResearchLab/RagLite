local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local FogParameters = require("Core.FileFormats.FogParameters")

local json = require("json")

local inputFilePath = "data/fogparametertable.txt"
printf("Exporting fog parameters: %s", inputFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local inputFileContents = grf:ExtractFileInMemory(inputFilePath)

grf:Close()

local fogParametersTable = FogParameters:DecodeFileContents(inputFileContents)

local outputFilePath = path.join("Exports", "fog-parameters.json")
local jsonFileContents = json.prettier(fogParametersTable)
printf("Saving fog parameters for %s maps: %s", table.count(fogParametersTable), outputFilePath)
C_FileSystem.WriteFile(outputFilePath, jsonFileContents)
