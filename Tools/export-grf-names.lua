local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local grfPath = arg[1] or "data.grf"

local grf = RagnarokGRF()
grf:Open(grfPath)
grf:Close()

local fileList = grf:GetFileList()

local originalFileNames = {}
for index, fileEntry in ipairs(fileList) do
	table.insert(originalFileNames, fileEntry.name)
end

table.sort(originalFileNames)

for index, fileName in ipairs(originalFileNames) do
	-- print(fileName)
end
