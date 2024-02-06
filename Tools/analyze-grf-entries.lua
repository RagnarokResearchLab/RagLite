local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)
grf:Close()

local fileList = grf:GetFileList()

local fileNames = {}
for index, fileEntry in ipairs(fileList) do
	table.insert(fileNames, fileEntry.name)
end

local maxPath, minPath
local totalPathLengths = 0
for index, name in ipairs(fileNames) do
	if not maxPath or #name > #maxPath then
		maxPath = name
	end

	if not minPath or #name < #minPath then
		minPath = name
	end

	totalPathLengths = totalPathLengths + #name
end

local numPaths = table.count(fileNames)
local avgPathLength = totalPathLengths / numPaths

printf("Number of file entries: %d", avgPathLength)
printf("Shortest file name: %s (%s)", minPath, #minPath)
printf("Longest file name: %s (%s)", maxPath, #maxPath)
printf("Total storage size: %s", string.filesize(totalPathLengths))
printf("Average length: %s", string.filesize(math.floor(avgPathLength + 0.5)))
