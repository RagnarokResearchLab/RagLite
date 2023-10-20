local BinaryReader = require("Core.FileFormats.BinaryReader")

local iconv = require("iconv")
local uv = require("uv")
local zlib = require("zlib")

local RagnarokRGZ = {
	MAX_FILE_SIZE = 0xFFFFFFFF, -- UINT32_MAX
	REASONABLE_FILE_SIZE_LIMIT = 1024 * 1024 * 100, -- 100 MB should be enough (and small enough to buffer)?
}

function RagnarokRGZ:Construct()
	local instance = {
		entries = {},
	}

	setmetatable(instance, self)

	return instance
end

function RagnarokRGZ:DecodeFileContents(fileContents)
	local decompressionStartTime = uv.hrtime()

	local LZLIB_GZIP_WINDOW_BITS = (15 + 16) -- windowBits + simple gzip header (see zlib docs)
	local inflate = zlib.inflate(LZLIB_GZIP_WINDOW_BITS)
	local decompressedFileContents = inflate(fileContents)

	local decompressionEndTime = uv.hrtime()
	local decompressionTimeInMilliseconds = (decompressionEndTime - decompressionStartTime) / 10E5
	printf("[RagnarokRGZ] Finished decompressing archive in %.2f ms", decompressionTimeInMilliseconds)

	self.reader = BinaryReader(decompressedFileContents)

	local decodingStartTime = uv.hrtime()

	self:DecodeEntries()

	local decodingEndTime = uv.hrtime()
	local decodingTimeInMilliseconds = (decodingEndTime - decodingStartTime) / 10E5
	printf("[RagnarokGR2] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)
end

function RagnarokRGZ:DecodeEntries()
	local reader = self.reader

	local caseSensitiveEntryType
	while caseSensitiveEntryType ~= "e" do
		caseSensitiveEntryType = reader:GetCountedString(1)

		assert(
			caseSensitiveEntryType == "d" -- Directory entry
				or caseSensitiveEntryType == "e" -- EOF
				or caseSensitiveEntryType == "f", -- File entry
			format("Invalid entry type %s (must be one of 'd', 'e', or 'f')", caseSensitiveEntryType)
		)

		local fileNameLength = reader:GetUnsignedInt8()
		assert(fileNameLength > 0, format("Invalid file length %s", fileNameLength))

		local fileName = reader:GetNullTerminatedString(fileNameLength)

		if caseSensitiveEntryType == "e" then
			assert(fileName == "end", "Unexpected file name %s for end-of-archive entry", fileName)
		end

		local unicodeFilePath = iconv.convert(fileName, "CP949", "UTF-8")

		local entry = {
			name = unicodeFilePath,
			type = caseSensitiveEntryType,
			size = 0,
			data = "",
		}

		if caseSensitiveEntryType == "f" then
			local fileSize = reader:GetUnsignedInt32()

			-- Note: This limitation is imposed by the format itself (due to using a uint32_t file size)
			-- Enforce it separately as it's extremely unlikely to change - patching with huge files would be insanity
			assert(
				fileSize <= RagnarokRGZ.MAX_FILE_SIZE,
				format("Invalid file size %s (max. 4GB are supported by the RGZ format)", fileSize)
			)

			-- Buffering a 4GB string would still be pretty bad, however. Doubt it'll ever happen, but just in case...
			assert(
				fileSize <= RagnarokRGZ.REASONABLE_FILE_SIZE_LIMIT,
				format("Refusing to buffer %s bytes in-memory (file size too large)", fileSize)
			)
			local fileContents = reader:GetCountedString(fileSize)
			entry.size = fileSize
			entry.data = fileContents
		end

		table.insert(self.entries, entry)
	end
end

RagnarokRGZ.__index = RagnarokRGZ
RagnarokRGZ.__call = RagnarokRGZ.Construct
setmetatable(RagnarokRGZ, RagnarokRGZ)

return RagnarokRGZ
