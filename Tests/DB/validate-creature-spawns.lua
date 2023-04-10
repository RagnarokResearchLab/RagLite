local validation = require("validation")
local validateTable = validation.validateTable

local spawnSchema = {
    spawnArea = {
        center = {
			u = validation.validateNumber,
			v = validation.validateNumber,
		},
        width = validation.validateNumber,
        height = validation.validateNumber,
    },
    amount = validation.validateNumber,
    creatureID = validation.validateString,	
    respawnStartTime = validation.validateNumber,
    respawnWindowSize = validation.validateNumber,
    respawnMode = validation.validateNumber,
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

local function validateCreatureSpawns(spawnsByMap)

	validateTable(spawnsByMap, "spawnsByMap")
    for mapID, mapSpawns in pairs(spawnsByMap) do
        for i, spawn in ipairs(mapSpawns) do
            validateTableRecursively(spawn, spawnSchema, "spawnsByMap." .. mapID .. "[" .. i .. "].")
        end
    end
end

local classicSpawns = dofile("DB/Creatures/classic-spawns.lua")
validateCreatureSpawns(classicSpawns)

local amatsuSpawns = dofile("DB/Creatures/amatsu-spawns.lua")
validateCreatureSpawns(amatsuSpawns)