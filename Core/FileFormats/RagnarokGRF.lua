local bit = require("bit")
local ffi = require("ffi")
local uv = require("uv")
local zlib = require("zlib")

local tonumber = tonumber

local bit_band = bit.band
local bit_rshift = bit.rshift
local ffi_cast = ffi.cast
local ffi_sizeof = ffi.sizeof
local ffi_string = ffi.string
local string_lower = string.lower

local RagnarokGRF = {
	MAGIC_HEADER = "Master of Magic",
	SCRAMBLING_OFFSET = 7, -- Presumably, arbitrary constant (for obfusciation purposes?)
	RAW_FILE_ENTRY_TYPE = 0,
	COMPRESSED_FILE_ENTRY_TYPE = 1,
	cdefs = [[
		#pragma pack(1)
		typedef struct {
			uint8_t signature[15];
			uint8_t key[15];
			uint32_t file_table_offset;
			uint32_t scrambling_seed;
			uint32_t file_count;
			uint32_t version;
		} grf_header_t;

		typedef struct {
			uint32_t compressed_size;
			uint32_t decompressed_size;
		} grf_file_table_t;

		typedef struct {
			uint32_t compressed_size;
			uint32_t byte_aligned_size; // Compressed, then padded to next 8 byte boundary?
			uint32_t decompressed_size;
			uint8_t node_type;
			uint32_t offset;
		} grf_file_entry_t;
	]],
	HEADER_SIZE_IN_BYTES = 46,
}

function RagnarokGRF:Construct()
	local instance = {
		fileTable = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokGRF.__index = RagnarokGRF
RagnarokGRF.__call = RagnarokGRF.Construct
setmetatable(RagnarokGRF, RagnarokGRF)

function RagnarokGRF:Open(pathToGRF)
	local isValidPath = C_FileSystem.Exists(pathToGRF)
	if not isValidPath then
		error(format("Failed to open archive %s (No such file exists)", pathToGRF), 0)
	end

	local isGRF = (path.extname(pathToGRF) == ".grf")
	if not isGRF then
		error(format("Failed to open archive %s (Not a .grf file)", pathToGRF), 0)
	end

	printf("[RagnarokGRF] Opening archive in read-only mode: %s", pathToGRF)
	self.fileHandle = assert(io.open(pathToGRF, "rb"))

	self:DecodeArchiveMetadata()
end

function RagnarokGRF:Close()
	self.fileHandle:close()
end

function RagnarokGRF:DecodeArchiveMetadata()
	local startTime = uv.hrtime()

	self:DecodeHeader()
	self:DecodeFileTable()

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokGRF] Finished decoding archive metadata in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokGRF:DecodeHeader()
	local headerSize = ffi_sizeof("grf_header_t")
	local headerBytes = self.fileHandle:read(headerSize)
	local header = ffi_cast("grf_header_t*", headerBytes)

	self.signature = ffi_string(header.signature)
	if self.signature ~= "Master of Magic" then
		error("Failed to decode GRF header (Signature " .. self.signature .. ' should be "Master of Magic"', 0)
	end

	self.encryptionKey = ffi_string(header.key)
	if self.encryptionKey ~= "" then
		error("Failed to decode GRF header (Encryption is not currently supported)", 0)
	end

	self.fileTableOffsetRelativeToHeader = tonumber(header.file_table_offset)
	self.scramblingSeed = tonumber(header.scrambling_seed)
	-- Naive scrambling algorithm? Or at least that's what I'm guessing is going on here...
	self.fileCount = tonumber(header.file_count) - tonumber(header.scrambling_seed) - RagnarokGRF.SCRAMBLING_OFFSET

	local major_version = bit_rshift(bit_band(header.version, 0xFF00), 8)
	local minor_version = bit_band(header.version, 0xFF)
	self.version = major_version + minor_version / 10
end

function RagnarokGRF:DecodeFileTable()
	self:DecodeTableHeader()
	self:DecodeFileEntries()
end

function RagnarokGRF:DecodeTableHeader()
	self.fileHandle:seek("set", self.fileTableOffsetRelativeToHeader + RagnarokGRF.HEADER_SIZE_IN_BYTES)

	local tableSize = ffi_sizeof("grf_file_table_t")
	local tableHeaderBytes = self.fileHandle:read(tableSize)
	local tableHeader = ffi_cast("grf_file_table_t*", tableHeaderBytes)

	self.fileTable.compressedSizeInBytes = tonumber(tableHeader.compressed_size)
	self.fileTable.decompressedSizeInBytes = tonumber(tableHeader.decompressed_size)
end

function RagnarokGRF:DecodeFileEntries()
	local compressedTableBytes = self.fileHandle:read(self.fileTable.compressedSizeInBytes)
	local decompressedTableBytes = zlib.inflate()(compressedTableBytes)

	local movingConversionPointer = ffi_cast("char*", decompressedTableBytes)

	local entries = {}
	for index = 0, self.fileCount - 1 do
		local normalizedCaseInsensitiveFilePath = self:DecodeFileName(movingConversionPointer)
		local numProcessedBytesToSkip = #normalizedCaseInsensitiveFilePath -- Normalization doesn't change the length
		movingConversionPointer = movingConversionPointer + numProcessedBytesToSkip + 1 -- \0 terminator

		-- Some redundancy could be removed here to reduce memory pressure, but it enables faster lookups
		local entry = ffi_cast("grf_file_entry_t*", movingConversionPointer)
		local fileEntry = {
			name = normalizedCaseInsensitiveFilePath,
			compressedSizeInBytes = tonumber(entry.compressed_size),
			byteAlignedSizeInBytes = tonumber(entry.byte_aligned_size),
			decompressedSizeInBytes = tonumber(entry.decompressed_size),
			typeID = tonumber(entry.node_type),
			offsetRelativeToHeader = tonumber(entry.offset),
		}
		entries[#entries + 1] = fileEntry
		entries[normalizedCaseInsensitiveFilePath] = fileEntry

		movingConversionPointer = movingConversionPointer + ffi_sizeof("grf_file_entry_t")
	end

	self.fileTable.entries = entries
end

function RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes)
	local name = ffi_string(pointerToNullTerminatedStringBytes)

	-- Converting to a standardized format avoids crossplatform headaches
	local normalizedFilePath = name:gsub("\\", "/")
	local normalizedCaseInsensitiveFilePath = normalizedFilePath:lower()

	return normalizedCaseInsensitiveFilePath
end

-- To measure (and optimize) the worst-case decompression time, it'll be convenient to find the largest files easily
function RagnarokGRF:FindLargestFileEntry()
	local largestEncounteredFileEntry
	local largestEncounteredFileSize = 0

	for index, entry in ipairs(self.fileTable.entries) do
		-- Ignore padding since it doesn't significantly affect the decompression times
		if entry.decompressedSizeInBytes > largestEncounteredFileSize then
			largestEncounteredFileEntry = entry
			largestEncounteredFileSize = entry.decompressedSizeInBytes
		end
	end

	return largestEncounteredFileEntry
end

function RagnarokGRF:ExtractFileToDisk(fileName, where)
	local fileContents = self:ExtractFileInMemory(fileName)
	C_FileSystem.WriteFile(where, fileContents)
end

function RagnarokGRF:ExtractFileInMemory(fileName)
	local timeBefore = uv.hrtime()

	-- Windows paths are problematic on other platforms
	fileName = string_lower(fileName)
	fileName = fileName:gsub("\\", "/")

	local entry = self.fileTable.entries[fileName]
	if not entry then
		error("Failed to extract file " .. fileName .. " (no such entry exists)", 0)
	end

	self.fileHandle:seek("set", entry.offsetRelativeToHeader + RagnarokGRF.HEADER_SIZE_IN_BYTES)

	local buffer = self.fileHandle:read(entry.byteAlignedSizeInBytes) -- Padding is discarded by decompressor
	if entry.typeID == RagnarokGRF.RAW_FILE_ENTRY_TYPE then
		return buffer
	end

	local timeAfterRead = uv.hrtime()

	local decompressedBuffer = zlib.inflate()(buffer)
	local timeAfterDecompress = uv.hrtime()

	local timeToRead = (timeAfterRead - timeBefore) / 10E5
	local timeToDecompress = (timeAfterDecompress - timeAfterRead) / 10E5

	printf(
		"[RagnarokGRF] Blocking read for %.2f ms; decompressed %d bytes in %.2f ms",
		timeToRead,
		entry.byteAlignedSizeInBytes,
		timeToDecompress
	)

	return decompressedBuffer
end

ffi.cdef(RagnarokGRF.cdefs)
assert(RagnarokGRF.HEADER_SIZE_IN_BYTES == ffi_sizeof("grf_header_t")) -- Basic sanity check

return RagnarokGRF
