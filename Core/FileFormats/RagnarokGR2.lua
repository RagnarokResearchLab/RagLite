local BinaryReader = require("Core.FileFormats.BinaryReader")

local openssl = require("openssl")
local uv = require("uv")

local RagnarokGR2 = {
	MAGIC_HEADER = string.lower("B867B0CAF86DB10F84728C7E5E19001E"),
	COMPRESSION_MODE_NONE = 0,
	COMPRESSION_MODE_OODLE = 1,
}

function RagnarokGR2:Construct()
	local instance = {}

	setmetatable(instance, self)

	return instance
end

function RagnarokGR2:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeFileHeader()
	self:DecodeSegmentHeaders()
	self:DecodeDataSegments()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokGR2] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokGR2:DecodeFileHeader()
	local reader = self.reader

	self.signature = openssl.hex(reader:GetCountedString(16))
	if self.signature ~= RagnarokGR2.MAGIC_HEADER then
		error(
			format(
				"Failed to decode GR2 header (Signature " .. self.signature .. ' should be "%s")',
				RagnarokGR2.MAGIC_HEADER
			),
			0
		)
	end

	self.headerSizeInBytes = reader:GetUnsignedInt32()
	assert(
		self.headerSizeInBytes == 352,
		format("Unexpected header size %s (should probably investigate?)", self.headerSizeInBytes)
	)
	self.unknownHeaderBytes = { -- Format identifier? (OpenGR2) -> Whatever, doesn't matter if it's always zero...
		reader:GetUnsignedInt32(),
		reader:GetUnsignedInt32(),
		reader:GetUnsignedInt32(),
	}
	assert(self.unknownHeaderBytes[1] == 0, "Unknown header bytes #1 are non-zero (should probably investigate?)")
	assert(self.unknownHeaderBytes[2] == 0, "Unknown header bytes #2 are non-zero (should probably investigate?)")
	assert(self.unknownHeaderBytes[3] == 0, "Unknown header bytes #3 are non-zero (should probably investigate?)")

	self.version = reader:GetUnsignedInt32()
	if self.version ~= 6.0 then
		error(format("Unsupported GR2 version %.1f", self.version), 0)
	end

	self.totalFileSizeInBytes = reader:GetUnsignedInt32()
	assert(
		self.totalFileSizeInBytes == reader.endOfFilePointer,
		format(
			"Stored GR2 file size %s doesn't match actual size %s",
			self.totalFileSizeInBytes,
			reader.endOfFilePointer
		)
	)

	self.checksum = reader:GetUnsignedInt32()

	self.segmentHeadersOffsetRelativeToFileHeader = reader:GetUnsignedInt32()
	self.numDataSegments = reader:GetUnsignedInt32()

	self.rootNodeInfo = {
		pointerToTypeNode = {
			dataSegmentID = reader:GetUnsignedInt32(),
			offsetFromStartOfSegment = reader:GetUnsignedInt32(),
		},
		pointerToRootNode = {
			dataSegmentID = reader:GetUnsignedInt32(),
			offsetFromStartOfSegment = reader:GetUnsignedInt32(),
		},
		versionTag = reader:GetUnsignedInt32(),
		customizedVersionTags = {
			reader:GetUnsignedInt32(),
			reader:GetUnsignedInt32(),
			reader:GetUnsignedInt32(),
			reader:GetUnsignedInt32(),
		},
	}

	assert(
		self.rootNodeInfo.versionTag == 2147483663,
		format("Unexpected root node version %s (should be %s)", self.rootNodeInfo.version, 2147483663)
	)
	assert(
		self.rootNodeInfo.customizedVersionTags[1] == 0,
		"Customized version tag #1 is non-zero (should probably investigate?)"
	)
	assert(
		self.rootNodeInfo.customizedVersionTags[2] == 0,
		"Customized version tag #2 is non-zero (should probably investigate?)"
	)
	assert(
		self.rootNodeInfo.customizedVersionTags[3] == 0,
		"Customized version tag #3 is non-zero (should probably investigate?)"
	)
	assert(
		self.rootNodeInfo.customizedVersionTags[4] == 0,
		"Customized version tag #4 is non-zero (should probably investigate?)"
	)
end

function RagnarokGR2:DecodeSegmentHeaders()
	local reader = self.reader

	local segmentHeaders = {}

	for segmentID = 1, self.numDataSegments do
		local segmentHeader = {
			compressionTypeID = reader:GetUnsignedInt32(),
			startOffsetRelativeToFile = reader:GetUnsignedInt32(),
			compressedSizeInBytes = reader:GetUnsignedInt32(),
			decompressedSizeInBytes = reader:GetUnsignedInt32(),
			alignmentInBytes = reader:GetUnsignedInt32(),
			compressorParameters = {
				firstTrackEndOffsetRelativeToSegment = reader:GetUnsignedInt32(),
				secondTrackEndOffsetRelativeToSegment = reader:GetUnsignedInt32(),
			},
			virtualPointerRelocationInfo = {
				offsetRelativeToFile = reader:GetUnsignedInt32(),
				numRequiredRelocations = reader:GetUnsignedInt32(),
			},
			endiannessRelocationInfo = {
				offsetRelativeToFile = reader:GetUnsignedInt32(),
				numRequiredRelocations = reader:GetUnsignedInt32(),
			},
		}

		table.insert(segmentHeaders, segmentHeader)
	end

	self.segmentHeaders = segmentHeaders
end

function RagnarokGR2:DecodeDataSegments()
	local reader = self.reader

	local dataSegments = {}

	for segmentID = 1, self.numDataSegments do
		local segment = {
			virtualPointerRelocations = {},
			endiannessRelocations = {},
		}

		local header = self.segmentHeaders[segmentID]
		local isCompressedSegment = (header.compressionTypeID ~= RagnarokGR2.COMPRESSION_MODE_NONE)
		printf(
			"[RagnarokGR2] NYI: Decoding %s data segment %d (offset: %s, compression mode: %d, compressed size: %s, decompressed size: %s, alignment: %s)",
			isCompressedSegment and "compressed" or "uncompressed",
			segmentID,
			header.startOffsetRelativeToFile,
			header.compressionTypeID,
			header.compressedSizeInBytes,
			header.decompressedSizeInBytes,
			header.alignmentInBytes
		)

		local numRequiredPointerRelocations = header.virtualPointerRelocationInfo.numRequiredRelocations
		printf("[RagnarokGR2] NYI: This segment requires %d pointer relocations", numRequiredPointerRelocations)

		for relocationID = 1, numRequiredPointerRelocations do
			local virtualPointerRelocationInfo = {
				fromOffsetRelativeToSegment = reader:GetUnsignedInt32(),
				targetSegmentID = reader:GetUnsignedInt32(),
				destinationOffsetRelativeToTargetSegment = reader:GetUnsignedInt32(),
			}
			table.insert(segment.virtualPointerRelocations, virtualPointerRelocationInfo)
		end

		local numRequiredEndiannessRelocations = header.endiannessRelocationInfo.numRequiredRelocations
		printf("[RagnarokGR2] NYI: This segment requires %d endianness relocations", numRequiredEndiannessRelocations)
		for relocationID = 1, numRequiredEndiannessRelocations do
			local endiannessRelocationInfo = {
				numEntriesToFix = reader:GetUnsignedInt32(), -- Entries = ? (unclear, should clarify later)
				startOffset = reader:GetUnsignedInt32(),
				targetSegmentID = reader:GetUnsignedInt32(),
				targetOffset = reader:GetUnsignedInt32(),
			}

			table.insert(segment.endiannessRelocations, endiannessRelocationInfo)
		end

		local segmentBytes = buffer.new(header.decompressedSizeInBytes)
		segmentBytes:put(reader:GetCountedString(header.compressedSizeInBytes))
		printf("[RagnarokGR2] Exporting %s data segment (for further analysis)", string.filesize(#segmentBytes))

		-- Cannot proceed here, for now (since Oodle decompression and relocations aren't supported)
		segment.bytes = debug.sbuf(segmentBytes) -- Not particularly useful, but oh well

		table.insert(dataSegments, segment)
	end

	self.dataSegments = dataSegments
end

local json = require("json")

function RagnarokGR2:ToJSON()
	local gr2 = {
		signature = self.signature,
		headerSizeInBytes = self.headerSizeInBytes,
		unknownHeaderBytes = self.unknownHeaderBytes,
		version = self.version,
		totalFileSizeInBytes = self.totalFileSizeInBytes,
		checksum = self.checksum,
		segmentHeadersOffsetRelativeToFileHeader = self.segmentHeadersOffsetRelativeToFileHeader,
		numDataSegments = self.numDataSegments,
		rootNodeInfo = self.rootNodeInfo,
		segmentHeaders = self.segmentHeaders,
		dataSegments = self.dataSegments,
	}

	return json.prettier(gr2)
end

RagnarokGR2.__index = RagnarokGR2
RagnarokGR2.__call = RagnarokGR2.Construct
setmetatable(RagnarokGR2, RagnarokGR2)

return RagnarokGR2
