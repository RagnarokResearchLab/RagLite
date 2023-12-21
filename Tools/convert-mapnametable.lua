local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local string_explode = string.explode
local string_gsub = string.gsub

local mode = arg[1] or "grf"
local source = arg[2]

local mapNameTable
if mode == "grf" then
	source = source or "data.grf"
	local grf = RagnarokGRF()
	grf:Open(source)
	mapNameTable = grf:ExtractFileInMemory("data/mapnametable.txt") -- Adjust path as needed (or extract from GRF)
elseif mode == "file" then
	source = source or "mapnametable.txt"
	mapNameTable = C_FileSystem.ReadFile(path.join("Exports", source))
else
	error("Inavalid mode (must be either 'grf' or 'file')")
end

C_FileSystem.WriteFile(path.join("Exports", "mapnametable.txt"), mapNameTable)

local mapNames = {}

local lines = string_explode(mapNameTable, "\r\n")

local function processLine(line)
	-- Drop comments and empty lines
	if line == "" or line:sub(1, 2) == "//" then
		return
	end

	local tokens = string_explode(line, "#") -- Assumes table is already cleaned-up
	local mapID = path.basename(tokens[1], ".rsw") -- Strip file extension
	local displayName = string_gsub(tokens[2], "%s$", "") -- Strip trailing whitespace

	mapNames[mapID] = displayName
end

for index, line in ipairs(lines) do
	processLine(line)
end

local existingMapDB = require("DB.Maps")

for mapID, mapInfo in pairs(existingMapDB) do
	-- Discard duplicates (keep the existing data as a priority as it may have been modified)
	mapNames[mapID] = mapInfo.displayName
end

local mapDB = {}
for mapID, displayName in pairs(mapNames) do
	mapDB[mapID] = {
		displayName = displayName,
	}
end

local outputFilePath = "DB/Maps.lua"
local luaImportString = "return \n" .. dump(mapDB)

printf("Saving %d map display names to %s", table.count(mapDB), outputFilePath)
C_FileSystem.WriteFile(outputFilePath, luaImportString)
