local bit = require("bit")
local ffi = require("ffi")
local uv = require("uv")
local zlib = require("zlib")

local tonumber = tonumber

local bit_band = bit.band
local bit_rshift = bit.rshift
local string_filesize = string.filesize
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
		pathToGRF = "",
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

	self.pathToGRF = pathToGRF

	self:DecodeArchiveMetadata()
end

function RagnarokGRF:Close()
	printf("[RagnarokGRF] Closing handle to archive: %s", self.pathToGRF)
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
		local normalizedCaseInsensitiveFilePath, numProcessedBytesToSkip = self:DecodeFileName(movingConversionPointer)
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
	local fileName = ffi_string(pointerToNullTerminatedStringBytes)

	-- Converting to a standardized format ASAP avoids crossplatform and encoding headaches
	local normalizedFileName = self:GetNormalizedFilePath(fileName)
	return normalizedFileName, #fileName
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

	local normalizedFileName = self:GetNormalizedFilePath(fileName)

	-- The name may already have been normalized if extracting based on the decoded file list
	local entry = self.fileTable.entries[normalizedFileName] or self.fileTable.entries[fileName]
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
		"[RagnarokGRF] Blocking read for %.2f ms; decompressed %s in %.2f ms",
		timeToRead,
		string_filesize(entry.byteAlignedSizeInBytes),
		timeToDecompress
	)

	return decompressedBuffer
end

function RagnarokGRF:IsFileEntry(fileName)
	local normalizedFileName = self:GetNormalizedFilePath(fileName)

	-- The name may already have been normalized if a proper unicode name was used
	local entry = self.fileTable.entries[normalizedFileName] or self.fileTable.entries[fileName]
	return entry ~= nil
end

function RagnarokGRF:GetFileList()
	return self.fileTable.entries
end

-- This probably should be moved elsewhere (later)
if ffi.os == "Windows" then
	ffi.cdef([[
		int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
		int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
	]])

	local CP949 = 949
	local CP_UTF8 = 65001

	function RagnarokGRF:DecodeMultiByteString(input)
		local unicodeLen = ffi.C.MultiByteToWideChar(CP949, 0, input, -1, nil, 0)
		local unicodeStr = ffi.new("wchar_t[?]", unicodeLen)
		ffi.C.MultiByteToWideChar(CP949, 0, input, -1, unicodeStr, unicodeLen)

		local outputLen = ffi.C.WideCharToMultiByte(CP_UTF8, 0, unicodeStr, -1, nil, 0, nil, nil)
		local outputStr = ffi.new("char[?]", outputLen)
		ffi.C.WideCharToMultiByte(CP_UTF8, 0, unicodeStr, -1, outputStr, outputLen, nil, nil)

		return ffi.string(outputStr)
	end
else
	ffi.cdef([[
		typedef void* iconv_t;
		iconv_t iconv_open(const char* tocode, const char* fromcode);
		size_t iconv(iconv_t cd, char** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft);
		int iconv_close(iconv_t cd);
	]])

	function RagnarokGRF:DecodeMultiByteString(input)
		local fromEncoding = "CP949"
		local toEncoding = "UTF-8"
		local cd = ffi.C.iconv_open(toEncoding, fromEncoding)
		if cd == ffi.cast("iconv_t", -1) then
			error("iconv_open failed: " .. ffi.string(ffi.C.strerror(ffi.errno())))
		end

		local inbuf = ffi.new("char*[1]", ffi.new("char[?]", #input + 1, input))
		local inbytesleft = ffi.new("size_t[1]", #input)
		local outbufSize = #input * 4 -- Worst case scenario for UTF-8
		local outbufStorage = ffi.new("char[?]", outbufSize) -- Storage for the output buffer
		local outbuf = ffi.new("char*[1]", outbufStorage) -- Pointer to the output buffer
		local outbytesleft = ffi.new("size_t[1]", outbufSize)

		if ffi.C.iconv(cd, inbuf, inbytesleft, outbuf, outbytesleft) == -1 then
			ffi.C.iconv_close(cd)
			error("iconv failed: " .. ffi.string(ffi.C.strerror(ffi.errno())))
		end

		ffi.C.iconv_close(cd)
		return ffi.string(outbufStorage) -- Construct the string from the start of the output buffer
	end
end

function RagnarokGRF:GetNormalizedFilePath(fileName)
	-- Must convert to UTF8 first to avoid operating on codepoints by accident
	fileName = self:DecodeMultiByteString(fileName)

	-- Windows paths are problematic on other platforms
	fileName = string_lower(fileName)
	fileName = fileName:gsub("\\", "/")

	-- HTTP route handlers may add this (it's unnecessary and not how GRF paths are stored)
	local firstCharacter = fileName:sub(1, 1)
	local isAbsolutePosixPath = (firstCharacter == "/")
	if isAbsolutePosixPath then
		fileName = fileName:sub(2)
	end

	-- Not sure why they're even in there - maybe accidentally used \\\\ to escape twice? Weird.
	fileName = fileName:gsub("//", "/")

	return fileName
end

ffi.cdef(RagnarokGRF.cdefs)
assert(RagnarokGRF.HEADER_SIZE_IN_BYTES == ffi_sizeof("grf_header_t")) -- Basic sanity check

return RagnarokGRF
