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
	printf("Dumping GR2 contents: %s", gr2FilePath)

	local gr2Bytes = grf:ExtractFileInMemory(gr2FilePath)
	local gr2 = RagnarokGR2()
	gr2:DecodeFileContents(gr2Bytes)

	local exportFilePathRoot = path.join("Exports", path.basename(gr2FilePath) .. ".json")
	C_FileSystem.WriteFile(exportFilePathRoot, gr2:ToJSON())
end

grf:Close()
