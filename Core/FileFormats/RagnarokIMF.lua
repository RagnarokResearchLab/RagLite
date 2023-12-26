local json = require("json")
local uv = require("uv")

local table_insert = table.insert

local BinaryReader = require("Core.FileFormats.BinaryReader")

local RagnarokIMF = {}

function RagnarokIMF:Construct()
	local instance = {}

	setmetatable(instance, self)

	return instance
end

RagnarokIMF.__index = RagnarokIMF
RagnarokIMF.__call = RagnarokIMF.Construct
setmetatable(RagnarokIMF, RagnarokIMF)

function RagnarokIMF:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeSpriteLayers()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure", numBytesRemaining)
	if not self.reader:HasReachedEOF() then
		error(eofErrorMessage, 0)
	end

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokIMF] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokIMF:DecodeHeader()
	local reader = self.reader

	self.version = reader:GetFloat()
	if self.version ~= 1.0099999904632569 then
		error(format("Unsupported IMF version %.2f", self.version), 0)
	end

	self.checksum = reader:GetInt32()
end

function RagnarokIMF:DecodeSpriteLayers()
	local reader = self.reader
	self.numSpriteLayers = reader:GetInt32()

	local zLayers = {}
	for layerID = 1, self.numSpriteLayers + 1, 1 do
		local zLayer = {
			numAnimations = reader:GetInt32(),
			animationLayers = {},
		}

		for animationID = 1, zLayer.numAnimations, 1 do
			local animationLayerInfo = {
				numAnimationFrames = reader:GetInt32(),
			}

			for frameID = 1, animationLayerInfo.numAnimationFrames, 1 do
				local zLayerInfo = {
					zIndex = reader:GetInt32(),
					origin = {
						u = reader:GetInt32(),
						v = reader:GetInt32(),
					},
				}
				table_insert(animationLayerInfo, zLayerInfo)
			end

			table_insert(zLayer.animationLayers, animationLayerInfo)
		end

		table_insert(zLayers, zLayer)
	end

	self.zLayers = zLayers
end

function RagnarokIMF:ToJSON()
	local imf = {
		version = self.version,
		checksum = self.checksum,
		numSpriteLayers = self.numSpriteLayers,
		zLayers = self.zLayers,
	}

	return json.prettier(imf)
end

return RagnarokIMF
