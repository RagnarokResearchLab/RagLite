local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local iconv = require("iconv")

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

local englishFileNames = {}
local koreanFileNames = {}

printf("Original file names: %d", #originalFileNames)

for index, fileName in ipairs(originalFileNames) do
	-- The heuristic is a little sketchy, but it should work in this context
	local asciiFileName = iconv.convert(fileName, "UTF-8", "CP949")
	local isEnglishFileName = (fileName == asciiFileName)
	if not isEnglishFileName then
		table.insert(koreanFileNames, fileName)
	else
		table.insert(englishFileNames, fileName)
	end
end

printf("English file names: %d", #englishFileNames)
printf("Korean file names: %d", #koreanFileNames)

assert(#englishFileNames + #koreanFileNames == #originalFileNames)