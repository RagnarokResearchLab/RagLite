local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")
local FileAnalyzer = require("Tools.FileAnalyzer")

local console = require("console")
local json = require("json")

local table_insert = table.insert

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local rswFileList = grf:FindFilesByType("rsw")
local gndFileList = grf:FindFilesByType("gnd")
local fileList = {}

for index, grfEntry in ipairs(rswFileList) do
	table_insert(fileList, grfEntry)
end

for index, grfEntry in ipairs(gndFileList) do
	table_insert(fileList, grfEntry)
end

AnimatedWaterPlane.PREALLOCATE_GEOMETRY_BUFFERS = false -- Will run OOM here if preallocating all these buffers

console.startTimer("Decoding resource files")
local decodedResources = {}
for index, entry in ipairs(fileList) do
	printf("Loading resource file: %s (memory usage: %s)", entry.name, string.filesize(collectgarbage("count") * 1024))
	local fileContents = grf:ExtractFileInMemory(entry.name)
	local source, destination
	if path.extname(entry.name) == ".rsw" then
		source = RagnarokRSW()
		destination = RagnarokRSW()
	elseif path.extname(entry.name) == ".gnd" then
		source = RagnarokGND()
		destination = RagnarokGND()
	else
		error("Unsupported file: " .. entry.name)
	end
	source:DecodeFileContents(fileContents)

	-- Reduce memory pressure by removing unused data (not ideal, still creates lots of garbage)
	local waterPlanes = source.waterPlanes -- Backup the relevant data first
	destination.waterPlanes = waterPlanes
	decodedResources[entry.name] = destination
end
console.stopTimer("Decoding resource files")

local analysisResult = FileAnalyzer:AnalyzeWaterPlanes(decodedResources)

local jsonFilePath = path.join("Exports", "water-types.json")
printf("Exporting analysis results to %s", jsonFilePath)
local jsonFileContents = json.prettier(analysisResult)
C_FileSystem.WriteFile(jsonFilePath, jsonFileContents)
