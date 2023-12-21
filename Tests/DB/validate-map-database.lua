local validation = require("validation")
local validateTable = validation.validateTable

local mapSchema = {
	displayName = validation.validateString,
}

local function validateTableRecursively(table, schema, prefix)
	prefix = prefix or ""
	for key, value in pairs(schema) do
		local field_name = prefix .. key
		if type(value) == "table" then
			validateTableRecursively(table[key], value, field_name .. ".")
		else
			value(table[key], field_name)
		end
	end
end

local function validateMapDB(mapDB)
	validateTable(mapDB, "mapDB")
	for mapID, mapInfo in pairs(mapDB) do
		validateTableRecursively(mapInfo, mapSchema, 'Maps["' .. mapID .. '"].')
	end
end

local mapDB = dofile("DB/Maps.lua")
validateMapDB(mapDB)
