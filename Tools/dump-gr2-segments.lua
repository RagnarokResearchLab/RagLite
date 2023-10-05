local RagnarokGR2 = require("Core.FileFormats.RagnarokGR2")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local filesToExport = {}

if not arg[1] then
	print("No args provided, exporting all discovered .gr2 files")
	local fileList = grf:GetFileList()
	for grfFilePath, entry in pairs(fileList) do
		if path.extname(grfFilePath) == ".gr2" then
			printf("Discovered relevant file: %s", grfFilePath)
			table.insert(filesToExport, grfFilePath)
		end
	end
else
	print("%s arguments provided, exporting those", #arg)
	dump(arg)
	filesToExport = unpack(arg)
end

for index, gr2FilePath in ipairs(filesToExport) do
	local gr2Bytes = grf:ExtractFileInMemory(gr2FilePath)
	local gr2 = RagnarokGR2()
	gr2:DecodeFileContents(gr2Bytes)

	for segmentID = 1, gr2.numDataSegments do
		local outputFilePath = path.join("Exports", format("%s.segments.%d.bin", path.basename(gr2FilePath), segmentID))
		printf("Dumping GR2 segment: %s", outputFilePath)
		C_FileSystem.WriteFile(outputFilePath, gr2.dataSegments[segmentID].bytes)
	end
end

grf:Close()
