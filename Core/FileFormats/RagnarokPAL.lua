local ffi = require("ffi")

local ffi_cast = ffi.cast
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof

local RagnarokPAL = {
	cdefs = [[
		typedef struct spr_rgba_color {
			uint8_t red;
			uint8_t green;
			uint8_t blue;
			uint8_t alpha;
		} spr_rgba_color_t;

		typedef struct spr_palette {
			spr_rgba_color_t colors[256];
		} spr_palette_t;
	]],
}

function RagnarokPAL:DecodeFileContents(fileContents)
	local endOfFileOffset = #fileContents
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")

	if type(fileContents) == "string" then -- Can't use Lua strings as a buffer directly
		fileContents = buffer.new(#fileContents):put(fileContents)
	end

	local bufferAreaStartPointer = fileContents:ref()
	local paletteBytes = ffi_cast("spr_palette_t*", bufferAreaStartPointer + paletteStartOffset)

	-- Must copy to create a GC anchor here before the buffer is collected (probably not a big deal?)
	local bmpColorPalette = ffi_new("spr_palette_t[1]", paletteBytes[0])
	local newColors = ffi_new("spr_palette_t")

	ffi_copy(newColors, bmpColorPalette[0], ffi_sizeof("spr_palette_t"))
	return newColors
end

ffi.cdef(RagnarokPAL.cdefs)

return RagnarokPAL
