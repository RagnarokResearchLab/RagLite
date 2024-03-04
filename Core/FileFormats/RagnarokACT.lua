local BinaryReader = require("Core.FileFormats.BinaryReader")

local json = require("json")
local uv = require("uv")

local table_insert = table.insert

local RagnarokACT = {
	UPDATE_INTERVAL_IN_MILLISECONDS = 24,
	IMAGE_TYPES = {
		[0] = "BITMAP",
		[1] = "TRUECOLOR",
	},
}

function RagnarokACT:Construct()
	local instance = {
		animationClips = {},
		animationEvents = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokACT.__index = RagnarokACT
RagnarokACT.__call = RagnarokACT.Construct
setmetatable(RagnarokACT, RagnarokACT)

function RagnarokACT:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeAnimationClips()
	self:DecodeAnimationEvents()
	self:DecodeFrameTimes()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokACT] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokACT:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(2)
	if self.signature ~= "AC" then
		error("Failed to decode ACT header (Signature " .. self.signature .. ' should be "AC")', 0)
	end

	local minorVersion = reader:GetUnsignedInt8()
	local majorVersion = reader:GetUnsignedInt8()
	self.version = majorVersion + minorVersion / 10
	if self.version < 2.0 or self.version > 2.5 then
		error(format("Unsupported ACT version %.1f", self.version), 0)
	end

	self.numAnimationClips = reader:GetUnsignedInt16()
	self.unknownHeaderField = reader:GetCountedString(10)
end

function RagnarokACT:DecodeAnimationClips()
	for clipID = 1, self.numAnimationClips do
		local clip = {
			numAnimationFrames = self.reader:GetUnsignedInt32(),
			animationFrames = {},
		}

		for frameID = 1, clip.numAnimationFrames do
			local frame = self:DecodeAnimationFrame()
			table_insert(clip.animationFrames, frame)
		end

		table_insert(self.animationClips, clip)
	end
end

function RagnarokACT:DecodeAnimationFrame()
	local reader = self.reader
	local frame = {
		spriteLayers = {},
		anchors = {},
		mysteryBytes = {
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
			reader:GetInt32(),
		},
		numSpriteLayers = reader:GetUnsignedInt32(),
	}

	for layerID = 1, frame.numSpriteLayers do
		local layer = self:DecodeSpriteLayer()
		table_insert(frame.spriteLayers, layer)
	end

	frame.animationEventID = reader:GetInt32() -- TBD Maybe in Arcturus?

	local hasSpriteAnchors = (self.version >= 2.3)

	frame.numAnchors = hasSpriteAnchors and reader:GetInt32() or 0
	for anchorID = 1, frame.numAnchors do
		local anchorPoint = {
			mysteryBytes = reader:GetInt32(),
			u = reader:GetInt32(),
			v = reader:GetInt32(),
			unknown = reader:GetInt32(),
		}
		table_insert(frame.anchors, anchorPoint)
		print("UNKNOWN: %d", anchorPoint.unknown)
	end

	return frame
end

function RagnarokACT:DecodeSpriteLayer()
	local reader = self.reader

	local layer = {
		position = {
			u = reader:GetInt32(),
			v = reader:GetInt32(),
		},
		spritesheetCellIndex = reader:GetInt32(),
		isMirroredV = (reader:GetInt32() == 1 and true or false),
		colorTint = {
			red = 1,
			green = 1,
			blue = 1,
			alpha = 1,
		},
		scale = {
			u = 1,
			v = 1,
		},
		rotationInDegrees = 0,
		imageType = RagnarokACT.IMAGE_TYPES.BITMAP,
	}

	if self.version >= 2.0 then -- TBD Arcturus? check versions branch
		layer.colorTint = {
			red = reader:GetUnsignedInt8() / 255,
			green = reader:GetUnsignedInt8() / 255,
			blue = reader:GetUnsignedInt8() / 255,
			alpha = reader:GetUnsignedInt8() / 255,
		}
		layer.scale.u = reader:GetFloat()

		if self.version < 2.4 then
			layer.scale.v = layer.scale.u
		else
			layer.scale.v = reader:GetFloat()
		end

		layer.rotationInDegrees = reader:GetInt32()
		layer.imageType = RagnarokACT.IMAGE_TYPES[reader:GetInt32()]
	end

	if self.version >= 2.5 then
		layer.imageDimensions = {
			u = reader:GetInt32(),
			v = reader:GetInt32(),
		}
	end

	return layer
end
function RagnarokACT:DecodeAnimationEvents()
	if self.version < 2.1 then
		return
	end

	local reader = self.reader
	self.numAnimationEvents = reader:GetInt32()
	for eventID = 1, self.numAnimationEvents do
		local eventName = reader:GetNullTerminatedString(40)
		table_insert(self.animationEvents, eventName)
	end
end

function RagnarokACT:DecodeFrameTimes()
	local reader = self.reader
	local hasIndividualFrameTimings = (self.version >= 2.2) -- TBD 2.3? Or do we have a 2.2 ACT? (anubis test file?)
	for animationClipID = 1, self.numAnimationClips do
		local ticksPerFrame = hasIndividualFrameTimings and reader:GetFloat() or 4
		local frameTimeInMilliseconds = RagnarokACT.UPDATE_INTERVAL_IN_MILLISECONDS * ticksPerFrame
		self.animationClips[animationClipID].frameDisplayTimeInMilliseconds = frameTimeInMilliseconds
	end
end

function RagnarokACT:ToJSON()
	local actInfo = {
		signature = self.signature,
		version = self.version,
		unknownHeaderField = self.unknownHeaderField,
		numAnimationClips = self.numAnimationClips,
		animationClips = self.animationClips,
		animationEvents = self.animationEvents,
	}

	return json.prettier(actInfo)
end

return RagnarokACT
