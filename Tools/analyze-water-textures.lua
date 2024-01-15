local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local json = require("json")
local miniz = require("miniz")

local WATER_TEXTURES_DIR = "data/texture/워터"

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local waterTexturePaths = {}
local expectedFileTypes = {
	[".jpg"] = true,
	-- For some unfathomable reason, there's thumbs.db in there (which should be ignored)
	[".db"] = false,
}

local fileList = grf:GetFileList()
for index, entry in ipairs(fileList) do
	local filePath = entry.name
	local extension = path.extname(filePath)
	if filePath:match(WATER_TEXTURES_DIR) then
		-- It's possible (but unexpected) that other image formats might be used for water textures in the future
		assert(expectedFileTypes[extension] ~= nil, "Unexpected texture type: " .. extension:upper())

		if expectedFileTypes[extension] == false then
			printf("Skipping irrelevant file: %s", filePath)
		else
			printf("Found water texture of type %s: %s", extension, filePath)
			table.insert(waterTexturePaths, filePath)
		end
	end
end

local waterTextureImages = {}
local imageDimensions = {
	widths = {},
	heights = {},
}

for index, filePath in ipairs(waterTexturePaths) do
	printf("Analyzing water texture: %s", filePath)
	local fileContents = grf:ExtractFileInMemory(filePath)

	local exportFilePath = path.join("Exports", "WaterTextures", path.basename(filePath))
	printf("Exporting texture image to %s", exportFilePath)
	C_FileSystem.MakeDirectoryTree(path.dirname(exportFilePath))
	C_FileSystem.WriteFile(exportFilePath, fileContents)

	local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(fileContents)

	assert(width == height, "Unexpected rectangular water texture: " .. filePath)
	assert(width == 128 or width == 256, "Unexpected texture size: " .. width)

	local textureInfo = {
		name = filePath,
		filesize = string.filesize(#rgbaImageBytes),
		bytes = #rgbaImageBytes,
		width = width,
		height = height,
		checksum = miniz.crc32(rgbaImageBytes),
	}
	table.insert(waterTextureImages, textureInfo)

	-- Can't export as JSON if it's a sparse array, so just hash the number values
	width = tostring(width)
	height = tostring(height)

	imageDimensions.widths[width] = imageDimensions.widths[width] or {}
	table.insert(imageDimensions.widths[width], filePath)
	imageDimensions.heights[height] = imageDimensions.heights[height] or {}
	table.insert(imageDimensions.heights[height], filePath)
end

grf:Close()

printf("Texture images: %d", #waterTexturePaths)
printf("Water types: %d", #waterTexturePaths / 32)

local NUM_FRAMES_PER_TEXTURE_ANIMATION = 32

print("Widths:")
for width, filePaths in pairs(imageDimensions.widths) do
	printf("  %s: %d images (%d water types)", width, #filePaths, #filePaths / NUM_FRAMES_PER_TEXTURE_ANIMATION)
	table.sort(filePaths)
end

print("Heights:")
for height, filePaths in pairs(imageDimensions.heights) do
	printf("  %s: %d images (%d water types)", height, #filePaths, #filePaths / NUM_FRAMES_PER_TEXTURE_ANIMATION)
	table.sort(filePaths)
end

local analysisResult = {
	dimensions = imageDimensions,
	textureInfo = waterTextureImages,
}

local jsonFilePath = path.join("Exports", "water-textures.json")
printf("Exporting analysis results to %s", jsonFilePath)
local jsonFileContents = json.prettier(analysisResult)
C_FileSystem.WriteFile(jsonFilePath, jsonFileContents)
