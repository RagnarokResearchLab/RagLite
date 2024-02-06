local BinaryReader = require("Core.FileFormats.BinaryReader")

local ffi = require("ffi")
local uv = require("uv")
local validation = require("validation")

local new = ffi.new
local sizeof = ffi.sizeof
local tonumber = tonumber
local table_new = table.new

local CompiledGRF = {
	CGRF_CACHE_DIRECTORY = "Cache",
	errorStrings = {
		INVALID_GRF_PATH = "Not a GRF file: %s",
	},
	cdefs = [[
		typedef struct cgrf_version_t {
			uint32_t major;
			uint32_t minor;
			uint32_t patch;
		} cgrf_version_t;

		typedef struct cgrf_header_t {
			char signature[4];
			cgrf_version_t semanticVersion;
			uint32_t fileCount;
		} cgrf_header_t;

		typedef struct cgrf_entry_t {
			uint8_t typeID;
			uint32_t alignedSizeInBytes;
			uint32_t compressedSizeInBytes;
			uint32_t decompressedSizeInBytes;
			uint32_t offsetRelativeToHeader;
			uint8_t variableLengthPathBufferSize;
		} cgrf_entry_t;
	]],
}

-- No support for this in the runtime, yet :/
local function FileSystem_GetLastModifiedTimestamp(fileSystemPath)
	local fileAttributes, errorMessage = uv.fs_stat(fileSystemPath)
	assert(fileAttributes, errorMessage)

	return fileAttributes.mtime
end

function CompiledGRF:IsCacheUpdated(grfFilePath)
	if not C_FileSystem.IsDirectory(CompiledGRF.CGRF_CACHE_DIRECTORY) then
		C_FileSystem.MakeDirectoryTree(CompiledGRF.CGRF_CACHE_DIRECTORY)
	end

	validation.validateString(grfFilePath, "grfFilePath")

	local extension = path.extname(grfFilePath)
	local isGRF = string.lower(extension) ~= ".grf"
	if not C_FileSystem.Exists(grfFilePath) or isGRF then
		error(format(CompiledGRF.errorStrings.INVALID_GRF_PATH, grfFilePath), 0)
	end

	local grfFileName = path.basename(grfFilePath, extension)
	local cgrfFilePath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, grfFileName .. ".cgrf")

	if not C_FileSystem.Exists(cgrfFilePath) then
		return false
	end

	local grfModifiedDate = FileSystem_GetLastModifiedTimestamp(grfFilePath)
	local cgrfModifiedDate = FileSystem_GetLastModifiedTimestamp(cgrfFilePath)

	local isCachedVersionMoreRecent = cgrfModifiedDate.sec >= grfModifiedDate.sec
		or (cgrfModifiedDate.sec == grfModifiedDate.sec and cgrfModifiedDate.nsec >= grfModifiedDate.nsec)

	return isCachedVersionMoreRecent
end

function CompiledGRF:CompileTableOfContents(grf)
	local fileList = grf:GetFileList()
	local cgrfBuffer = buffer.new(1024)

	local header = new("cgrf_header_t")
	header.signature = "CGRF"
	header.semanticVersion.major = 1
	header.semanticVersion.minor = 0
	header.semanticVersion.patch = 0
	header.fileCount = grf.fileCount

	cgrfBuffer:putcdata(header, sizeof(header))

	for index, entry in ipairs(fileList) do
		local cgrfEntry = new("cgrf_entry_t")
		cgrfEntry.typeID = entry.typeID
		cgrfEntry.alignedSizeInBytes = entry.alignedSizeInBytes
		cgrfEntry.compressedSizeInBytes = entry.compressedSizeInBytes
		cgrfEntry.decompressedSizeInBytes = entry.decompressedSizeInBytes
		cgrfEntry.offsetRelativeToHeader = entry.offsetRelativeToHeader
		cgrfEntry.variableLengthPathBufferSize = #entry.name

		local variableLengthFilePath = new("char[?]", #entry.name + 1, entry.name)
		cgrfBuffer:putcdata(cgrfEntry, sizeof(cgrfEntry))
		cgrfBuffer:putcdata(variableLengthFilePath, #entry.name)
	end

	return tostring(cgrfBuffer)
end

function CompiledGRF:RestoreTableOfContents(grf, cgrfBuffer)
	local reader = BinaryReader(cgrfBuffer)

	local header = new("cgrf_header_t")
	header.signature = reader:GetCountedString(sizeof(header.signature))
	header.semanticVersion.major = reader:GetUnsignedInt32()
	header.semanticVersion.minor = reader:GetUnsignedInt32()
	header.semanticVersion.patch = reader:GetUnsignedInt32()
	header.fileCount = reader:GetUnsignedInt32()

	local entries = table_new(header.fileCount, 0)
	for index = 1, tonumber(header.fileCount), 1 do
		local cgrfEntry = reader:GetTypedArray("cgrf_entry_t", 1)[0]
		local normalizedFilePath = reader:GetCountedString(cgrfEntry.variableLengthPathBufferSize)

		-- Copying the data here isn't ideal, but the GRF interface expects Lua types and not cdata
		local backwardsCompatibleLuaFileEntry = {
			alignedSizeInBytes = tonumber(cgrfEntry.alignedSizeInBytes),
			compressedSizeInBytes = tonumber(cgrfEntry.compressedSizeInBytes),
			decompressedSizeInBytes = tonumber(cgrfEntry.decompressedSizeInBytes),
			name = normalizedFilePath,
			offsetRelativeToHeader = tonumber(cgrfEntry.offsetRelativeToHeader),
			typeID = tonumber(cgrfEntry.typeID),
		}
		entries[normalizedFilePath] = backwardsCompatibleLuaFileEntry
		entries[index] = backwardsCompatibleLuaFileEntry
	end

	grf.fileTable.compressedSizeInBytes = 0
	grf.fileTable.decompressedSizeInBytes = 0
	grf.fileTable.entries = entries
end

ffi.cdef(CompiledGRF.cdefs)

return CompiledGRF
