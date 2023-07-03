local console = require("console")
local ffi = require("ffi")
local stbi = require("stbi")

local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local assert = assert
local math_floor = math.floor

local gndFileName = arg[1] or "geffen"
local gndFilePath = "data/" .. gndFileName .. ".gnd"
printf("Dumping GND lightmap: %s", gndFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local gndBytes = grf:ExtractFileInMemory(gndFilePath)
local gnd = RagnarokGND()
gnd:DecodeFileContents(gndBytes)
grf:Close()

console.startTimer("Lightmap Texture Generation")

local textureImageWidth = gnd.gridSizeU * gnd.lightmapFormat.pixelWidth
local textureImageHeight = gnd.gridSizeV * gnd.lightmapFormat.pixelHeight
local shadowmapPixels = ffi.new("stbi_unsigned_char_t[?]", textureImageWidth * textureImageHeight * 4)
local lightmapPixels = ffi.new("stbi_unsigned_char_t[?]", textureImageWidth * textureImageHeight * 4)

for pixelV = 0, textureImageHeight - 1, 1 do
	for pixelU = 0, textureImageWidth - 1, 1 do
		local pixelIndex = pixelU + pixelV * textureImageWidth

		local gridU = math_floor(pixelU / gnd.lightmapFormat.pixelWidth)
		local gridV = math_floor(pixelV / gnd.lightmapFormat.pixelHeight)
		local cubeIndex = gridU + gnd.gridSizeU * gridV

		local cube = gnd.cubeGrid[cubeIndex]
		local surfaceTop = gnd.texturedSurfaces[cube.top_surface_id]
		assert(surfaceTop, "No TOP surface was assigned to the GND cube")
		local lightmapSlice = gnd.lightmapSlices[surfaceTop.lightmap_slice_id]
		assert(lightmapSlice, "No lightmap slice was assigned to the TOP surface")

		local texelU = pixelU % gnd.lightmapFormat.pixelWidth
		local texelV = pixelV % gnd.lightmapFormat.pixelHeight
		local texelID = texelU + texelV * gnd.lightmapFormat.pixelWidth

		assert(texelID <= 63, "Invalid texel ID (UV calculation must be wrong)")

		local OFFSET_RED, OFFSET_GREEN, OFFSET_BLUE, OFFSET_ALPHA = 0, 1, 2, 3
		local TEXEL_START_OFFSET = 3 * texelID
		local PIXEL_START_OFFSET = 4 * pixelIndex

		local opacity = lightmapSlice.ambient_occlusion_texels[texelID]
		local red = lightmapSlice.baked_lightmap_texels[TEXEL_START_OFFSET + OFFSET_RED]
		local green = lightmapSlice.baked_lightmap_texels[TEXEL_START_OFFSET + OFFSET_GREEN]
		local blue = lightmapSlice.baked_lightmap_texels[TEXEL_START_OFFSET + OFFSET_BLUE]

		shadowmapPixels[PIXEL_START_OFFSET + OFFSET_RED] = opacity
		shadowmapPixels[PIXEL_START_OFFSET + OFFSET_GREEN] = opacity
		shadowmapPixels[PIXEL_START_OFFSET + OFFSET_BLUE] = opacity
		shadowmapPixels[PIXEL_START_OFFSET + OFFSET_ALPHA] = 255

		lightmapPixels[PIXEL_START_OFFSET + OFFSET_RED] = red
		lightmapPixels[PIXEL_START_OFFSET + OFFSET_GREEN] = green
		lightmapPixels[PIXEL_START_OFFSET + OFFSET_BLUE] = blue
		lightmapPixels[PIXEL_START_OFFSET + OFFSET_ALPHA] = 255
	end
end

console.stopTimer("Lightmap Texture Generation")

stbi.bindings.stbi_flip_vertically_on_write(true)

local function ExportHumandReadableTextureImageAsPNG(pixelBuffer, outputFileName)
	local textureImage = ffi.new("stbi_image_t")
	textureImage.width = textureImageWidth
	textureImage.height = textureImageHeight
	textureImage.data = pixelBuffer
	textureImage.channels = 4 -- RGBA

	local maxFileSize = stbi.max_bitmap_size(textureImage.width, textureImage.height, textureImage.channels)
	local fileContents = buffer.new(maxFileSize)
	local startPointer, length = fileContents:reserve(maxFileSize)
	local numBytesWritten = stbi.bindings.stbi_encode_png(textureImage, startPointer, length, 0)

	assert(numBytesWritten > 0, "Failed to encode PNG contents")

	fileContents:commit(numBytesWritten)
	C_FileSystem.WriteFile(outputFileName, tostring(fileContents))
end

ExportHumandReadableTextureImageAsPNG(shadowmapPixels, "shadowmap.png")
ExportHumandReadableTextureImageAsPNG(lightmapPixels, "lightmap.png")

stbi.bindings.stbi_flip_vertically_on_write(false)
