local Color = require("Core.NativeClient.DebugDraw.Color")

local pairs = pairs
local tonumber = tonumber
local string_gsub = string.gsub
local string_match = string.match

local FogParameters = {}

function FogParameters:DecodeFileContents(fileContents)
	local lastEncounteredMap = nil
	local numAddedLines = 0

	local results = {}
	local lines = string.explode(fileContents, "\r\n")
	for index, line in ipairs(lines) do
		local isMapID = self:IsMapID(line)
		if isMapID then
			local mapFileName = self:StripHashTag(line)
			local mapID = path.basename(mapFileName, ".rsw")

			lastEncounteredMap = {
				mapID = mapID,
				params = {},
			}
		end

		if lastEncounteredMap ~= nil then -- In the process of building a fog table entry
			numAddedLines = numAddedLines + 1
			lastEncounteredMap.params[numAddedLines] = line
		end

		if numAddedLines == 5 then -- Got them all, save the entry for future postprocessing
			results[lastEncounteredMap.mapID] = lastEncounteredMap
			-- Reset
			lastEncounteredMap = nil
			numAddedLines = 0
		end
	end

	local output = {}

	for mapID, properties in pairs(results) do
		local near = self:StripHashTag(properties.params[2])
		local far = self:StripHashTag(properties.params[3])
		local hexColor = self:StripHashTag(properties.params[4])
		local density = self:StripHashTag(properties.params[5])
		local color = Color:HexStringToRGBA(hexColor)
		output[mapID] = {
			near = tonumber(near),
			far = tonumber(far),
			color = { -- Can't serialize cdata as JSON
				red = color.red,
				green = color.green,
				blue = color.blue,
				alpha = color.alpha,
			},
			density = tonumber(density),
		}
	end

	return output
end

function FogParameters:IsMapID(line)
	return string_match(line, ".rsw")
end

function FogParameters:StripHashTag(line)
	return string_gsub(line, "#", "")
end

return FogParameters
