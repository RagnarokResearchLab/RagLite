local json = require("json")

local string_explode = string.explode
local string_gsub = string.gsub

local mapNameTable = C_FileSystem.ReadFile("mapnametable.txt") -- Adjust path as needed (or extract from GRF)

local mapNames = {}

local lines = string_explode(mapNameTable, "\n")
for index, line in ipairs(lines) do
	local tokens = string_explode(line, "#") -- Assumes table is already cleaned-up
	local mapID = path.basename(tokens[1], ".rsw") -- Strip file extension
	local displayName = string_gsub(tokens[2], "%s$", "") -- Strip trailing whitespace

	mapNames[mapID] = displayName
end

mapNames.login_screen = "Login Screen" -- Entry point (arbitrary)

local outputFilePath = "DB/map-display-names.json"
printf("Saving JSON-encoded display names to %s", outputFilePath)

local jsonString = json.prettier(mapNames)
C_FileSystem.WriteFile(outputFilePath, jsonString)
