local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local iconv = require("iconv")
local json = require("json")

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

-- The heuristic is a little sketchy, but it should work in this context
local function IsEnglishPhrase(phrase)
	local asciiPhrase = iconv.convert(phrase, "UTF-8", "CP949")
	local isEnglishPhrase = (phrase == asciiPhrase)
	return isEnglishPhrase
end

printf("Original file names: %d", #originalFileNames)

for index, fileName in ipairs(originalFileNames) do
	if not IsEnglishPhrase(fileName) then
		table.insert(koreanFileNames, fileName)
	else
		table.insert(englishFileNames, fileName)
	end
end

printf("English file names: %d", #englishFileNames)
printf("Korean file names: %d", #koreanFileNames)

assert(#englishFileNames + #koreanFileNames == #originalFileNames)

local koreanWordsOrPhrases = {}

for index, fileName in ipairs(koreanFileNames) do
	local tokens = string.explode(fileName, "/") -- Paths are normalized so this is fine
	-- print(fileName, #tokens)
	for _, token in ipairs(tokens) do
		-- print(_, token)
		if not IsEnglishPhrase(token) then
			-- print(token)
			-- TODO strip file extension (don't need to translate it)
			token = path.basename(token)
			-- table.insert(koreanWordsOrPhrases, token)
			koreanWordsOrPhrases[token] = token
		end
	end
end

-- TODO sort, filter out duplicates
-- dump(koreanWordsOrPhrases)

printf("Number of Korean phrases or tokens: %d", table.count(koreanWordsOrPhrases))

local localizationTable = json.prettier(koreanWordsOrPhrases)
local outputFilePath = path.join("Exports", "grf-names-kr.json")
printf("Storing localization table: %s", outputFilePath)

C_FileSystem.WriteFile(outputFilePath, localizationTable)