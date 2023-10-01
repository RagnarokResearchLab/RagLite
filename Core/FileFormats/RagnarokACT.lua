local BinaryReader = require("Core.FileFormats.BinaryReader")

local ffi = require("ffi")
local uv = require("uv")

local table_insert = table.insert

local RagnarokACT = {
	cdefs = [[
		#pragma pack(1)
		// Somewhat redundant, consolidate later
		typedef struct act_vector_t {
			uint32_t u;
			uint32_t v;
		} act_vector_t;

		typedef struct act_vec2f_t {
			float u;
			float v;
		} act_vec2f_t;

		typedef struct act_rgba_color_t {
			uint8_t red;
			uint8_t green;
			uint8_t blue;
			uint8_t alpha; // TBD unused or not?
		} act_rgba_color_t;

		typedef struct act_image_transform_t {
			act_vec2f_t scale;
			float rotation_deg;
		} act_image_transform_t;

		typedef struct act_sprite_layer_t {
			act_vector_t position;
			uint32_t spritesheet_cell_index;
			uint32_t feature_flags; // mirror only?
			act_rgba_color_t color_tint;
			act_image_transform_t transform;
			uint32_t image_type_id; // 0 = bmp, 1 = tga
			act_vector_t image_dimensions; // TBD does it always match the SPR size?
		} act_sprite_layer_t;

		typedef struct act_sprite_anchor_t {
		//	uint8_t unknown_anchor_properties[4]; // tbd
			act_vector_t offset;
			uint32_t unknown_anchor_property; // tbd
		
		} act_sprite_anchor_t;
	]],
	-- ACT_IMAGE_TYPE_BITMAP = 0
	-- ACT_IMAGE_TYPE_TRUECOLOR = 1
}

function RagnarokACT:Construct()
	local instance = {
		-- numAnimationClips = act.numAnimationClips,
		-- animationClips = act.animationClips,
		animationClips = {},
		-- animationEvents = act.animationEvents,
		animationEvents = {},
		-- timings = act.timings,
		timings = {},
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
	-- self:DecodeAnimationEvents()
	-- self:DecodeTimingIntervals()

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokACT] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokACT:DecodeHeader(fileContents)
	local reader = self.reader

	self.signature = reader:GetCountedString(2)
	if self.signature ~= "AC" then
		-- error("Failed to decode ACT header (Signature " .. self.signature .. ' should be "AC")', 0)
	end

	local minorVersion = reader:GetUnsignedInt8()
	local majorVersion = reader:GetUnsignedInt8()
	self.version = majorVersion + minorVersion / 10
	-- if self.version < 2.4 or self.version > 2.5 then
	-- if self.version == 2.0 then
	-- error(format("Unsupported ACT version %.1f", self.version), 0)
	-- end

	self.numAnimationClips = reader:GetUnsignedInt16()
	self.unknownHeaderField = reader:GetCountedString(10)
end

function RagnarokACT:DecodeAnimationClips()
	self.animationClips = {}
	-- for clipID = 1, self.numAnimationClips do
	local clip = {
		numAnimationFrames = self.reader:GetUnsignedInt16(),
		animationFrames = {},
	}
	local frame = self:DecodeAnimationFrame()
	table_insert(clip.animationFrames, frame)
	table_insert(self.animationClips, clip)

	-- end
end

function RagnarokACT:DecodeAnimationFrame()
	local reader = self.reader
	local frame = {

		spriteLayers = {},
		anchors = {},
		mysteryBox1 = { -- TBD vec cdata?
			bottomLeftCorner = {
				u = reader:GetInt32(),
				v = reader:GetInt32(),
			},

			topRightCorner = {
				u = reader:GetInt32(),
				v = reader:GetInt32(),
			},
		},
		mysteryBox2 = {
			bottomLeftCorner = {
				u = reader:GetInt32(),
				v = reader:GetInt32(),
			},

			topRightCorner = {
				u = reader:GetInt32(),
				v = reader:GetInt32(),
			},
		},
		animationEventTypeID = reader:GetInt32(),
		numSpriteLayers = reader:GetUnsignedInt32(),
	}

	-- local layers = reader:GetTypedArray("act_sprite_layer_t", frame.numSpriteLayers)
	-- for layerID = 1, frame.numSpriteLayers do
		-- table_insert(frame.spriteLayers, layers[layerID-1])
	-- end
	
	-- frame.numAnchors = reader:GetInt32()
	-- local anchors = reader:GetTypedArray("act_sprite_anchor_t", frame.numAnchors)
	-- for anchorID= 1, frame.numAnchors do
		-- table_insert(frame.anchors, anchors[anchorID-1])
	-- end

	return frame
end

-- function RagnarokACT:DecodeSpriteLayer()
-- 	local layer = {}

-- 	return layer
-- end

-- function RagnarokACT:DecodeAnchorPoint()
-- 	local anchor = {}

-- 	return anchor
-- end

function RagnarokACT:DecodeAnimationEvents()
	local reader = self.reader

	self.numAnimationEvents = reader:GetUnsignedInt32()
	local event = {}

	return event
end

function RagnarokACT:DecodeTimingIntervals()
	-- TBD
end

ffi.cdef(RagnarokACT.cdefs)

return RagnarokACT
