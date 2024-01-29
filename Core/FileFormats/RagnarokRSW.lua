local ffi = require("ffi")
local uv = require("uv")

local tonumber = tonumber
local ffi_string = ffi.string
local tinsert = table.insert

local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local BinaryReader = require("Core.FileFormats.BinaryReader")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local QuadTreeRange = require("Core.FileFormats.RSW.QuadTreeRange")

local RagnarokRSW = {
	SCENE_OBJECT_TYPE_ANIMATED_PROP = 1,
	SCENE_OBJECT_TYPE_DYNAMIC_LIGHT_SOURCE = 2,
	SCENE_OBJECT_TYPE_SPATIAL_AUDIO_SOURCE = 3,
	SCENE_OBJECT_TYPE_PARTICLE_EFFECT_EMITTER = 4,
	ANIMATION_TYPE_NONE = 0,
	ANIMATION_TYPE_ONCE = 1,
	ANIMATION_TYPE_LOOPING = 2,
	PROP_COLLISION_TYPE_SOLID = 0, -- Kind of guessing here, since most props use this value
	cdefs = [[
		#pragma pack(1)
		typedef struct rsw_header_t {
			char signature[4];
			uint8_t version_major;
			uint8_t version_minor;
		} rsw_header_t;

		// This seems a bit redundant?
		typedef struct rsw_rgb_color_t {
			float red;
			float green;
			float blue;
		} rsw_rgb_color_t;

		typedef struct rsw_lighting_info_t {
			uint32_t longitude;
			uint32_t latitude;
			rsw_rgb_color_t diffuse_color;
			rsw_rgb_color_t ambient_color;
			float shadowmap_alpha;
		} rsw_lighting_info_t;

		typedef struct rsw_bounding_box_t {
			int32_t top;
			int32_t bottom;
			int32_t left;
			int32_t right;
		} rsw_bounding_box_t;

		// Also redundant...
		typedef struct rsw_vector_t {
			float x;
			float y;
			float z;
		} rsw_vector_t;

		typedef struct rsw_prop_t {
			char name[40]; // 40
			int32_t animation_type_id; // 44
			float animation_speed; // 48
			int32_t block_type_id; // 52
			char rsm_model_name[80]; // 132
			char rsm_node_name[80]; // 212
			rsw_vector_t position; // 224
			rsw_vector_t rotation; // 236
			rsw_vector_t scale; // 248
		} rsw_prop_t;

		typedef struct rsw_renewal_prop_t {
			char name[40]; // 40
			int32_t animation_type_id; // 44
			float animation_speed; // 48
			int32_t block_type_id; // 52
			uint8_t mystery_byte; // 53
			char rsm_model_name[80]; // 133
			char rsm_node_name[80]; // 213
			rsw_vector_t position; // 225
			rsw_vector_t rotation; // 237
			rsw_vector_t scale; // 249
		} rsw_renewal_prop_t;

		typedef struct rsw_dynamic_light_t {
			char name[80];
			rsw_vector_t position;
			rsw_rgb_color_t color;
			float range;
		} rsw_dynamic_light_t;

		typedef struct rsw_audio_source_t {
			char name[80];
			char sound_file_path[80];
			rsw_vector_t position;
			float volume;
			int32_t width;
			int32_t height;
			float range;
			float cycle_interval;
		} rsw_audio_source_t;

		typedef struct rsw_particle_emitter_t {
			char name[80];
			rsw_vector_t position;
			int32_t effect_id;
			float emission_speed;
			float launch_parameters[4];
		} rsw_particle_emitter_t;

	]],
}

function RagnarokRSW:Construct()
	local instance = {
		waterPlanes = {},
		animatedProps = {},
		dynamicLightSources = {},
		spatialAudioSources = {},
		particleEffectEmitters = {},
		sceneGraph = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokRSW.__index = RagnarokRSW
RagnarokRSW.__call = RagnarokRSW.Construct
setmetatable(RagnarokRSW, RagnarokRSW)

function RagnarokRSW:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeIncludeFiles()
	self:DecodeWaterPlanes()
	self:DecodeEnvironmentalLightSources()
	self:DecodeMapBoundaries()
	self:DecodeSceneObjects()
	self:DecodeSceneGraphQuadTree()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokRSW] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokRSW:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(4)
	if self.signature ~= "GRSW" then
		error("Failed to decode RSW header (Signature " .. self.signature .. ' should be "GRSW")', 0)
	end

	local versionMajor = reader:GetUnsignedInt8()
	local versionMinor = reader:GetUnsignedInt8() / 10
	self.version = versionMajor + versionMinor

	assert(self.version >= 1.9 and self.version <= 2.6, "Unsupported RSW version " .. self.version)

	self.buildNumber = 0
	if self.version >= 2.2 and self.version < 2.5 then
		self.buildNumber = reader:GetUnsignedInt8()
	end

	if self.version >= 2.5 then
		self.buildNumber = reader:GetUnsignedInt32()
	end

	self.unknownRenderFlag = (self.version >= 2.5) and reader:GetUnsignedInt8() or 0
end

function RagnarokRSW:DecodeIncludeFiles()
	local reader = self.reader
	local includePathLength = 40

	self.iniFile = reader:GetNullTerminatedString(includePathLength)
	self.gndFile = reader:GetNullTerminatedString(includePathLength)
	self.gatFile = reader:GetNullTerminatedString(includePathLength)
	self.scrFile = reader:GetNullTerminatedString(includePathLength)
end

function RagnarokRSW:DecodeWaterPlanes()
	if self.version >= 2.6 then
		return -- Renewal format: Water plane has been moved to the GND file
	end

	local reader = self.reader
	local waterPlane = AnimatedWaterPlane(1, 1, {
		normalizedSeaLevel = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		textureTypePrefix = reader:GetInt32(),
		waveformAmplitudeScalingFactor = reader:GetFloat(),
		waveformPhaseShiftInDegreesPerFrame = reader:GetFloat(),
		waveformFrequencyInDegrees = reader:GetFloat(),
		textureDisplayDurationInFrames = reader:GetInt32(),
	})

	table.insert(self.waterPlanes, waterPlane)

	self.numWaterPlanesU = 1
	self.numWaterPlanesV = 1
end

function RagnarokRSW:DecodeEnvironmentalLightSources()
	local environmentalLightInfo = self.reader:GetTypedArray("rsw_lighting_info_t")

	local directionalLight = {
		longitudeInDegrees = tonumber(environmentalLightInfo.longitude),
		latitudeInDegrees = tonumber(environmentalLightInfo.latitude),
		diffuseColor = {
			red = tonumber(environmentalLightInfo.diffuse_color.red),
			green = tonumber(environmentalLightInfo.diffuse_color.green),
			blue = tonumber(environmentalLightInfo.diffuse_color.blue),
		},
	}

	local ambientLight = {
		diffuseColor = {
			red = tonumber(environmentalLightInfo.ambient_color.red),
			green = tonumber(environmentalLightInfo.ambient_color.green),
			blue = tonumber(environmentalLightInfo.ambient_color.blue),
		},
	}

	-- Composite blending (additive + multiplicative components) ~> scenewide color tint
	local contrastCorrectionColor = {
		red = (directionalLight.diffuseColor.red + ambientLight.diffuseColor.red)
			- directionalLight.diffuseColor.red * ambientLight.diffuseColor.red,
		green = (directionalLight.diffuseColor.green + ambientLight.diffuseColor.green)
			- directionalLight.diffuseColor.green * ambientLight.diffuseColor.green,
		blue = (directionalLight.diffuseColor.blue + ambientLight.diffuseColor.blue)
			- directionalLight.diffuseColor.blue * ambientLight.diffuseColor.blue,
	}

	self.directionalLight = directionalLight
	self.ambientLight = ambientLight
	self.contrastCorrectionColor = contrastCorrectionColor
	self.prebakedShadowmapAlpha = tonumber(environmentalLightInfo.shadowmap_alpha)
end

function RagnarokRSW:DecodeMapBoundaries()
	local outerWorldBoundingBox = self.reader:GetTypedArray("rsw_bounding_box_t")

	-- Shouldn't these be Y-inverted, if they're actually used? (Doesn't seem that way, though)
	self.boundingBox = {
		top = tonumber(outerWorldBoundingBox.top),
		bottom = tonumber(outerWorldBoundingBox.bottom),
		left = tonumber(outerWorldBoundingBox.left),
		right = tonumber(outerWorldBoundingBox.right),
	}
end

function RagnarokRSW:DecodeSceneObjects()
	local reader = self.reader

	local numSceneObjects = reader:GetInt32()
	for objectID = 0, numSceneObjects - 1, 1 do
		local objectTypeID = reader:GetInt32()
		if objectTypeID == RagnarokRSW.SCENE_OBJECT_TYPE_ANIMATED_PROP then
			self:DecodeAnimatedProps()
		elseif objectTypeID == RagnarokRSW.SCENE_OBJECT_TYPE_DYNAMIC_LIGHT_SOURCE then
			self:DecodeDynamicLightSource()
		elseif objectTypeID == RagnarokRSW.SCENE_OBJECT_TYPE_SPATIAL_AUDIO_SOURCE then
			self:DecodeSpatialAudioSource()
		elseif objectTypeID == RagnarokRSW.SCENE_OBJECT_TYPE_PARTICLE_EFFECT_EMITTER then
			self:DecodeParticleEffectEmitter()
		else
			local errorMessage = format(
				"Encountered unknown scene object type %d at index %d / %d (virtual file pointer is at %d / %d)",
				objectTypeID,
				objectID,
				numSceneObjects - 1,
				self.reader.virtualFilePointer,
				self.reader.endOfFilePointer
			)
			error(errorMessage, 0)
		end
	end

	assert(
		numSceneObjects
			== (
				#self.animatedProps
				+ #self.particleEffectEmitters
				+ #self.dynamicLightSources
				+ #self.spatialAudioSources
			),
		"Inconsistent number of scene objects detected (something almost certainly went horribly wrong?)"
	)

	self.numSceneObjects = numSceneObjects
end

function RagnarokRSW:DecodeAnimatedProps()
	local reader = self.reader

	local prop
	local objectInfo = {}

	-- Since 2.5 introduces build numbers already this could (in theory) cause some headaches...
	assert(self.version >= 2.6 or self.buildNumber < 162, "Unexpected build number detected (Isn't RSW 2.6 required?)")

	if self.version >= 2.6 and self.buildNumber > 161 then
		prop = reader:GetTypedArray("rsw_renewal_prop_t")
		objectInfo.unknownMysteryByte = tonumber(prop.mystery_byte)
	else
		prop = reader:GetTypedArray("rsw_prop_t")
		objectInfo.unknownMysteryByte = 0
	end

	objectInfo.name = ffi_string(prop.name)
	objectInfo.animationTypeID = tonumber(prop.animation_type_id)
	objectInfo.animationSpeedPercentage = tonumber(prop.animation_speed)
	objectInfo.isSolid = tonumber(prop.block_type_id) == RagnarokRSW.PROP_COLLISION_TYPE_SOLID

	objectInfo.rsmFile = ffi_string(prop.rsm_model_name)
	objectInfo.rsmNodeName = ffi_string(prop.rsm_node_name)
	objectInfo.normalizedWorldPosition = {
		x = prop.position.x * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		y = -1 * prop.position.y * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		z = prop.position.z * RagnarokGND.NORMALIZING_SCALE_FACTOR,
	}
	objectInfo.rotation = {
		x = tonumber(prop.rotation.x),
		y = tonumber(prop.rotation.y),
		z = tonumber(prop.rotation.z),
	}
	objectInfo.scale = {
		x = tonumber(prop.scale.x),
		y = tonumber(prop.scale.y),
		z = tonumber(prop.scale.z),
	}

	assert(objectInfo.animationSpeedPercentage > 0, "Encountered prop with negative animation speed (WTF?))")
	assert(objectInfo.animationSpeedPercentage <= 100, "Encountered prop with animation speed above 100% (WTF?)")

	tinsert(self.animatedProps, objectInfo)
end

function RagnarokRSW:DecodeDynamicLightSource()
	local objectInfo = self.reader:GetTypedArray("rsw_dynamic_light_t")

	-- Garbage data exists in gl_step: See https://github.com/RagnarokResearchLab/RagLite/issues/343
	if not objectInfo.position.y then
		objectInfo.position.y = -1 * 5 * 29.8 -- Denormalized Y of nearby light sources (workaround)
	end

	local lightSource = {
		name = ffi_string(objectInfo.name),
		normalizedWorldPosition = {
			x = objectInfo.position.x * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * objectInfo.position.y * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = objectInfo.position.z * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		diffuseColor = {
			red = tonumber(objectInfo.color.red),
			green = tonumber(objectInfo.color.green),
			blue = tonumber(objectInfo.color.blue),
		},
		normalizedFalloffDistanceInWorldUnits = objectInfo.range * RagnarokGND.NORMALIZING_SCALE_FACTOR,
	}

	tinsert(self.dynamicLightSources, lightSource)
end

function RagnarokRSW:DecodeSpatialAudioSource()
	local reader = self.reader
	local objectInfo = {
		name = reader:GetNullTerminatedString(80),
		soundFile = reader:GetNullTerminatedString(80),
		normalizedWorldPosition = {
			x = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		volumeGain = reader:GetFloat(),
		width = reader:GetInt32(),
		height = reader:GetInt32(),
		normalizedRangeInWorldUnits = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		cycleIntervalInMilliseconds = 6000, -- Duration of se_field_wind_03.wav
	}

	if self.version >= 2.1 then
		objectInfo.cycleIntervalInMilliseconds = reader:GetFloat() * 1000 -- Seconds to ms
	end

	if objectInfo.cycleIntervalInMilliseconds == 0 then
		-- Look no further than moc_fild16 to witness all available sound channels being blown out by this nonsense
		objectInfo.cycleIntervalInMilliseconds = 6000 -- Duration of se_field_wind_03.wav
	end

	-- Obsolete, but useful for analysis (disable the above override to see where things fall apart)
	assert(
		objectInfo.cycleIntervalInMilliseconds > 0,
		format(
			"Bugged audio source %s detected (a cycle interval of %s ms is clearly invalid)",
			objectInfo.name,
			objectInfo.cycleIntervalInMilliseconds
		)
	)

	tinsert(self.spatialAudioSources, objectInfo)
end

function RagnarokRSW:DecodeParticleEffectEmitter()
	local emitter = self.reader:GetTypedArray("rsw_particle_emitter_t")

	-- Decouple emission delay from the actual frame rate because it's the sane thing to do
	local expectedFPS = 60
	local particleEmissionDelayInSeconds = emitter.emission_speed / expectedFPS

	local objectInfo = {
		name = ffi_string(emitter.name),
		normalizedWorldPosition = {
			x = emitter.position.x * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * emitter.position.y * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = emitter.position.z * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		effectID = emitter.effect_id,
		emissionDelayInMilliseconds = particleEmissionDelayInSeconds * 1000, -- Seconds to ms
		launchParameters = {
			emitter.launch_parameters[0],
			emitter.launch_parameters[1],
			emitter.launch_parameters[2],
			emitter.launch_parameters[3],
		},
	}
	tinsert(self.particleEffectEmitters, objectInfo)
end

function RagnarokRSW:DecodeSceneGraphQuadTree()
	if self.version < 2.1 then
		return
	end

	self.sceneGraph = QuadTreeRange(self.reader, 0)
end

ffi.cdef(RagnarokRSW.cdefs)

return RagnarokRSW
