local ffi = require("ffi")
local transform = require("transform")

local tonumber = tonumber
local format = string.format
local string_sub = string.sub
local transform_bold = transform.bold

local Color = {
	WHITE = { red = 1, green = 1, blue = 1 },
	RED = { red = 1, green = 0, blue = 0 },
	GREEN = { red = 0, green = 1, blue = 0 },
	BLUE = { red = 0, green = 0, blue = 1 },
	YELLOW = { red = 1, green = 1, blue = 0 },
	MAGENTA = { red = 1, green = 0, blue = 1 },
	CYAN = { red = 0, green = 1, blue = 1 },
	PINK = { red = 1, green = 0x7F / 255, blue = 1 }, -- Fallback color (diffuse textures)
	SKY = { red = 0, green = 0x77 / 255, blue = 1 }, -- Clear color (game world)
	GREY = { red = 0.05, green = 0.05, blue = 0.05 }, -- Clear color (development)
}

ffi.cdef([[
	typedef struct Color {
		float red;
		float green;
		float blue;
		float alpha;
	} Color;
]])

function Color:HexStringToRGBA(hexColorString)
	local color = ffi.new("Color")

	local hexAlpha = string_sub(hexColorString, 3, 4)
	local hexRed = string_sub(hexColorString, 5, 6)
	local hexGreen = string_sub(hexColorString, 7, 8)
	local hexBlue = string_sub(hexColorString, 9, 10)

	local alpha = tonumber(hexAlpha, 16)
	local red = tonumber(hexRed, 16)
	local green = tonumber(hexGreen, 16)
	local blue = tonumber(hexBlue, 16)

	color.red = red / 255
	color.green = green / 255
	color.blue = blue / 255
	color.alpha = alpha / 255

	return color
end

function Color:__tostring()
	local formatted = {
		red = format("%.3f", self.red),
		green = format("%.3f", self.green),
		blue = format("%.3f", self.blue),
		alpha = format("%.3f", self.alpha),
	}
	local firstRow = format(
		"{ red = %s, green = %s, blue = %s, alpha = %s }",
		formatted.red,
		formatted.green,
		formatted.blue,
		formatted.alpha
	)
	return format("%s %s", transform_bold("Color"), firstRow)
end

Color.__index = Color

return ffi.metatype("Color", Color)
