local BinaryReader = require("Core.FileFormats.BinaryReader")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local bit = require("bit")
local ffi = require("ffi")
local uv = require("uv")

local binary_and = bit.band
local format = string.format

local RagnarokGAT = {
	OBSTRUCTED_TERRAIN_BITMASK = 0x01,
	SNIPABLE_TERRAIN_BITMASK = 0x02,
	WATER_TERRAIN_BITMASK = 0x04,
	cdefs = [[
		#pragma pack(1)
		typedef struct gat_tile_t {
			float altitude_southwest;
			float altitude_southeast;
			float altitude_northwest;
			float altitude_northeast;
			uint16_t terrain_flags;
			uint16_t renewal_water_flag;
		} gat_tile_t;

	]],
}

function RagnarokGAT:Construct()
	local instance = {}

	setmetatable(instance, self)

	return instance
end

RagnarokGAT.__index = RagnarokGAT
RagnarokGAT.__call = RagnarokGAT.Construct
setmetatable(RagnarokGAT, RagnarokGAT)

function RagnarokGAT:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeCollisionMap()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokGAT] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokGAT:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(4)
	if self.signature ~= "GRAT" then
		error("Failed to decode GAT header (Signature " .. self.signature .. ' should be "GRAT")', 0)
	end

	local majorVersion = reader:GetUnsignedInt8()
	local minorVersion = reader:GetUnsignedInt8()
	self.version = majorVersion + minorVersion / 10
	if self.version < 1.2 or self.version > 1.3 then
		error(format("Unsupported GAT version %.1f", self.version), 0)
	end

	self.mapU = reader:GetUnsignedInt32()
	self.mapV = reader:GetUnsignedInt32()
end

function RagnarokGAT:DecodeCollisionMap()
	local numTiles = self.mapU * self.mapV
	self.collisionMap = self.reader:GetTypedArray("gat_tile_t", numTiles)
end

function RagnarokGAT:IsValidMapPosition(mapU, mapV)
	local isPositionOutOfBounds = (mapU < 1 or mapV < 1 or mapU > self.mapU or mapV > self.mapV)
	return not isPositionOutOfBounds
end

function RagnarokGAT:MapPositionToTileID(mapU, mapV)
	if not self:IsValidMapPosition(mapU, mapV) then
		return nil,
			format(
				"Map position (%s, %s) is outside the actual map boundaries of (%s, %s)",
				mapU,
				mapV,
				self.mapU,
				self.mapV
			)
	end

	return (mapU - 1) + (mapV - 1) * self.mapU
end

function RagnarokGAT:IsObstructedTerrain(mapU, mapV)
	local tileID, errorMessage = self:MapPositionToTileID(mapU, mapV)
	if errorMessage then -- Indicate hard failure here to avoid glitches going unnoticed
		return error(errorMessage, 0)
	end

	return binary_and(self.collisionMap[tileID].terrain_flags, RagnarokGAT.OBSTRUCTED_TERRAIN_BITMASK) ~= 0
end

function RagnarokGAT:IsTerrainBlockingRangedAttacks(mapU, mapV)
	local tileID, errorMessage = self:MapPositionToTileID(mapU, mapV)
	if errorMessage then -- Indicate hard failure here to avoid glitches going unnoticed
		return error(errorMessage, 0)
	end

	return binary_and(self.collisionMap[tileID].terrain_flags, RagnarokGAT.SNIPABLE_TERRAIN_BITMASK) == 0
end

function RagnarokGAT:IsWater(mapU, mapV)
	local tileID, errorMessage = self:MapPositionToTileID(mapU, mapV)
	if errorMessage then -- Indicate hard failure here to avoid glitches going unnoticed
		return error(errorMessage, 0)
	end

	return binary_and(self.collisionMap[tileID].terrain_flags, RagnarokGAT.WATER_TERRAIN_BITMASK) ~= 0
end

function RagnarokGAT:GetTerrainAltitudeAt(mapU, mapV)
	local tileID, errorMessage = self:MapPositionToTileID(mapU, mapV)
	if errorMessage then -- Indicate hard failure here to avoid glitches going unnoticed
		return error(errorMessage, 0)
	end

	local averageTerrainAltitude = (
		self.collisionMap[tileID].altitude_southwest
		+ self.collisionMap[tileID].altitude_southeast
		+ self.collisionMap[tileID].altitude_northwest
		+ self.collisionMap[tileID].altitude_northeast
	) / 4

	-- GAT height vectors are given in RO's inverted coordinate system, which arguably isn't sane
	local normalizedTerrainAltitude = -1 * averageTerrainAltitude * RagnarokGND.NORMALIZING_SCALE_FACTOR
	return normalizedTerrainAltitude
end

ffi.cdef(RagnarokGAT.cdefs)

return RagnarokGAT
