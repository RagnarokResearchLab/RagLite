local assertions = require("assertions")
local iconv = require("iconv")
local json = require("json")
local uv = require("uv")

local assert = assert
local assertEqualNumbers = assertions.assertEqualNumbers
local table_insert = table.insert

local Matrix4D = require("Core.VectorMath.Matrix4D")
local Vector3D = require("Core.VectorMath.Vector3D")

local BinaryReader = require("Core.FileFormats.BinaryReader")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local RagnarokRSM = {
	SHADING_MODE_UNLIT = 0,
	SHADING_MODE_FLAT = 1,
	SHADING_MODE_SMOOTH = 2,
	TEXTUREANIMATION_TRANSLATE_U = 0,
	TEXTUREANIMATION_TRANSLATE_V = 1,
	TEXTUREANIMATION_MULTIPLY_U = 2,
	TEXTUREANIMATION_MULTIPLY_V = 3,
	TEXTUREANIMATION_ROTATE_UV = 4,
}

function RagnarokRSM:Construct()
	local instance = {
		texturePaths = {},
		rootNodes = {},
		meshes = {},
		scaleKeyframes = {},
		boundingBoxes = {},
	}

	setmetatable(instance, {
		__index = self,
	})

	return instance
end

class("RagnarokRSM", RagnarokRSM)

function RagnarokRSM:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeNodeHierarchy()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure", numBytesRemaining)
	if not self.reader:HasReachedEOF() then
		error(eofErrorMessage, 0)
	end

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokRSM] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokRSM:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(4)
	if self.signature ~= "GRSM" then
		error("Failed to decode RSM header (Signature " .. self.signature .. ' should be "GRSM")', 0)
	end

	local versionMajor = reader:GetUnsignedInt8()
	local versionMinor = reader:GetUnsignedInt8() / 10
	self.version = versionMajor + versionMinor

	local isSupportedRSM1 = (self.version >= 1.4 and self.version <= 1.5)
	local isSupportedRSM2 = (self.version >= 2.2 and self.version <= 2.3)
	local isUnsupportedVersion = not isSupportedRSM1 and not isSupportedRSM2
	if isUnsupportedVersion then
		error(format("Unsupported RSM version %.1f", self.version), 0)
	end
end

function RagnarokRSM:DecodeNodeHierarchy()
	local reader = self.reader

	local animationLength = reader:GetInt32() -- Format depends on the version
	-- 1.x: Loop animation after <length> ms
	self.animationDurationInMilliseconds = animationLength
	self.shadingModeID = reader:GetInt32()

	self.opacity = 1
	self.opacity = reader:GetUnsignedInt8() / 255

	self.animationFPS = 60
	self.numAnimationFramesPerCycle = self.animationDurationInMilliseconds / 1000 * self.animationFPS
	if self.version >= 2.2 then
		self.animationFPS = reader:GetFloat()

		-- 2.x: Loop animation after <length> frames
		self.numAnimationFramesPerCycle = animationLength
		self.animationDurationInMilliseconds = (self.numAnimationFramesPerCycle / self.animationFPS) * 1000
	else
		self.mysteryBytes = reader:GetCountedString(16) -- Probably unused garbage bytes?
		assert(self.mysteryBytes == string.rep("\000", 16), self.mysteryBytes)
	end

	self:DecodeTexturePaths()
	self:DecodeRootNodes()
	self:DecodeMeshNodes()
	self:DecodePositionAnimationKeyframes()
	self:DecodeScalingAnimationKeyframes()
	self:DecodeOptionalBoundingBoxes()
end

function RagnarokRSM:DecodeTexturePaths()
	local reader = self.reader

	if self.version >= 2.3 then
		-- Textures are stored on a per-mesh basis here
		return
	end

	if self.version == 2.2 then
		local numTextures = reader:GetInt32()
		for textureID = 1, numTextures, 1 do
			local numCharactersToRead = reader:GetInt32()
			local texturePath = reader:GetNullTerminatedString(numCharactersToRead)
			table_insert(self.texturePaths, RagnarokGRF:DecodeFileName(texturePath))
		end

		return
	end

	-- Fixed-size strings with a null terminator are used in legacy versions only
	local numTextures = reader:GetInt32()
	for textureID = 1, numTextures, 1 do
		local texturePath = reader:GetNullTerminatedString(40)
		table_insert(self.texturePaths, RagnarokGRF:DecodeFileName(texturePath))
	end
end

function RagnarokRSM:DecodeRootNodes()
	local reader = self.reader

	if self.version >= 2.2 then
		local numRootNodes = reader:GetInt32()
		for rootNodeID = 1, numRootNodes, 1 do
			local numCharactersToRead = reader:GetInt32()
			local rootNodeName = reader:GetNullTerminatedString(numCharactersToRead)
			table_insert(self.rootNodes, rootNodeName)
		end

		return
	end

	-- Only one root node can exist in legacy versions
	local rootNodeName = reader:GetNullTerminatedString(40)
	table_insert(self.rootNodes, rootNodeName)
end

function RagnarokRSM:DecodeMeshNodes()
	local reader = self.reader

	local numMeshes = reader:GetInt32()
	for meshID = 1, numMeshes, 1 do
		local mesh = self:DecodeMeshNode()
		table_insert(self.meshes, mesh)
	end
end

function RagnarokRSM:DecodeMeshNode()
	local mesh = {
		name = "",
		parentNodeName = "",

		textureIndices = {},
		texturePaths = {},
		vertices = {},
		textureVertices = {},
		triFaces = {},
		scaleKeyframes = {},
		rotationKeyframes = {},
		translationKeyframes = {},
		textureAnimations = {},
	}

	local reader = self.reader

	if self.version >= 2.2 then
		local numCharactersToRead = reader:GetInt32()
		mesh.name = reader:GetNullTerminatedString(numCharactersToRead)
		mesh.name = iconv.convert(mesh.name, "CP949", "UTF-8") or ""
		numCharactersToRead = reader:GetInt32()
		mesh.parentNodeName = reader:GetNullTerminatedString(numCharactersToRead)
		mesh.parentNodeName = iconv.convert(mesh.parentNodeName, "CP949", "UTF-8") or ""
	else
		mesh.name = reader:GetNullTerminatedString(40)
		mesh.name = iconv.convert(mesh.name, "CP949", "UTF-8") or ""
		mesh.parentNodeName = reader:GetNullTerminatedString(40)
		mesh.parentNodeName = iconv.convert(mesh.parentNodeName, "CP949", "UTF-8") or ""
	end

	if self.version >= 2.3 then
		local numTexturePaths = reader:GetInt32()
		for textureID = 1, numTexturePaths, 1 do
			local numCharactersToRead = reader:GetInt32()
			local texturePath = reader:GetNullTerminatedString(numCharactersToRead)
			table_insert(mesh.texturePaths, RagnarokGRF:DecodeFileName(texturePath))
		end
	else
		local numTextureIndices = reader:GetInt32()
		for textureID = 1, numTextureIndices, 1 do
			local textureIndex = reader:GetInt32()
			table_insert(mesh.textureIndices, textureIndex)
		end
	end

	mesh.initialPlacementMatrix = Matrix4D()
	mesh.initialPlacementMatrix:SetColumn(1, reader:GetFloat(), reader:GetFloat(), reader:GetFloat(), 0)
	mesh.initialPlacementMatrix:SetColumn(2, reader:GetFloat(), reader:GetFloat(), reader:GetFloat(), 0)
	mesh.initialPlacementMatrix:SetColumn(3, reader:GetFloat(), reader:GetFloat(), reader:GetFloat(), 0)

	if self.version >= 2.2 then
		-- Transforms are baked into geometry and/or animation keyframes; these properties are therefore unused
		mesh.initialPlacementMatrix:SetColumn(4, 0, 0, 0, 1)
		mesh.positionRelativeToParentNode = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat())
		mesh.rotationAngleInRadians = 0
		mesh.rotationAxis = Vector3D(0, 0, 0)
		mesh.scale = Vector3D(1, 1, 1)
	else
		-- Legacy mode: Transforms need to be baked in while generating the actual geometry
		mesh.initialPlacementMatrix:SetColumn(4, reader:GetFloat(), reader:GetFloat(), reader:GetFloat(), 1)
		mesh.positionRelativeToParentNode = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat())
		mesh.rotationAngleInRadians = reader:GetFloat()
		mesh.rotationAngleInDegrees = mesh.rotationAngleInRadians * 180 / math.pi

		mesh.rotationAxis = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat())
		mesh.scale = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat())
	end

	local numVertices = reader:GetInt32()
	for vertexID = 1, numVertices, 1 do
		local vertex = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat())
		table_insert(mesh.vertices, vertex)
	end

	local numTextureVertices = reader:GetInt32()
	for vertexID = 1, numTextureVertices, 1 do
		local textureVertex = {
			color = {
				alpha = reader:GetUnsignedInt8(),
				red = reader:GetUnsignedInt8(),
				green = reader:GetUnsignedInt8(),
				blue = reader:GetUnsignedInt8(),
			},
			u = reader:GetFloat(),
			v = reader:GetFloat(),
		}
		table_insert(mesh.textureVertices, textureVertex)
	end

	local numTriFaces = reader:GetInt32()
	for triFaceID = 1, numTriFaces, 1 do
		local triFace = {}

		triFace.smoothingGroupSizeInBytes = 24 -- One smoothing group entry (for the entire face)
		if self.version >= 2.2 then
			-- Looks like the smoothing groups became a VLA (implicit size + array elements at the end)
			triFace.smoothingGroupSizeInBytes = reader:GetInt32()
			assert(triFace.smoothingGroupSizeInBytes % 4 == 0, triFace.smoothingGroupSizeInBytes)
		end
		local numFixedStructBytes = 6 + 6 + 2 + 2 + 4 -- Everything except the smoothing group IDs
		local smoothingGroupArraySizeInBytes = triFace.smoothingGroupSizeInBytes - numFixedStructBytes
		local numSmoothingGroupIDs = smoothingGroupArraySizeInBytes / 4

		triFace.vertexIDs = {
			reader:GetUnsignedInt16(),
			reader:GetUnsignedInt16(),
			reader:GetUnsignedInt16(),
		}

		triFace.textureVertexIDs = {
			reader:GetUnsignedInt16(),
			reader:GetUnsignedInt16(),
			reader:GetUnsignedInt16(),
		}

		triFace.textureID = reader:GetUnsignedInt16()
		triFace.padding = reader:GetUnsignedInt16()
		local disableBackFaceCullingFlag = reader:GetInt32()
		triFace.isTwoSided = (disableBackFaceCullingFlag == 1)

		triFace.smoothingGroupIDs = {}
		for smoothingGroupID = 1, numSmoothingGroupIDs, 1 do
			triFace.smoothingGroupIDs[smoothingGroupID] = reader:GetInt32()
		end

		table_insert(mesh.triFaces, triFace)
	end

	if self.version >= 2.2 then
		local numScaleKeyframes = reader:GetInt32()
		for animationFrameID = 1, numScaleKeyframes, 1 do
			local scalingKeyframe = {
				frameID = reader:GetInt32(),
				scale = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
				mysteryBytes = reader:GetFloat(),
			}
			table_insert(mesh.scaleKeyframes, scalingKeyframe)
		end
	end

	local numRotationKeyframes = reader:GetInt32()
	for animationFrameID = 1, numRotationKeyframes, 1 do
		local rotationKeyframe = {
			frameID = reader:GetInt32(),
			rotationQuaternion = {
				x = reader:GetFloat(),
				y = reader:GetFloat(),
				z = reader:GetFloat(),
				w = reader:GetFloat(),
			},
		}
		table_insert(mesh.rotationKeyframes, rotationKeyframe)
	end

	if self.version >= 2.2 then
		local numTranslationKeyframes = reader:GetInt32()
		for animationFrameID = 1, numTranslationKeyframes, 1 do
			local translationKeyframe = {
				frameID = reader:GetInt32(),
				translationVector = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
				mysteryBytes = reader:GetFloat(),
			}
			assertEqualNumbers(translationKeyframe.mysteryBytes, 0, 1E-3)
			table_insert(mesh.translationKeyframes, translationKeyframe)
		end
	end

	if self.version >= 2.3 then
		local numTextureAnimations = reader:GetInt32()
		for textureAnimationID = 1, numTextureAnimations, 1 do
			local textureAnimation = {
				textureID = reader:GetInt32(),
				numAnimations = reader:GetInt32(),
				keyframes = {},
			}

			for animationID = 1, textureAnimation.numAnimations, 1 do
				local animationTypeID = reader:GetInt32()
				assert(
					animationTypeID >= RagnarokRSM.TEXTUREANIMATION_TRANSLATE_U
						and animationTypeID <= RagnarokRSM.TEXTUREANIMATION_ROTATE_UV
				)
				local numAnimationFrames = reader:GetInt32()

				textureAnimation.keyframes[animationTypeID] = {}

				for animationFrameID = 1, numAnimationFrames, 1 do
					local textureAnimationKeyframe = {
						frameID = reader:GetInt32(),
						offset = reader:GetFloat(),
					}

					table_insert(textureAnimation.keyframes[animationTypeID], textureAnimationKeyframe)
				end
			end

			table_insert(mesh.textureAnimations, textureAnimation)
		end
	end

	return mesh
end

function RagnarokRSM:DecodePositionAnimationKeyframes()
	-- This is sketchy: Piecing together info from FlavioJS, Temtaime & Tokei, here's my best guess:
	-- Originally there must have been position & scaling animations, one per file (for the main node)
	-- They were clearly never used and apparently removed/replaced by the RSM2 system later
	-- However, in RSM 1.5 there's still some unaccounted bytes at the end, so I assume that's why

	if self.version ~= 1.5 then
		-- No extra bytes present in 1.4, nor after the RSM2 revamp
		return
	end

	-- Could also be something else entirely (needs more research/testing)
	local numLegacyPositionAnimations = self.reader:GetInt32()
	assert(numLegacyPositionAnimations == 0, numLegacyPositionAnimations)
end

function RagnarokRSM:DecodeScalingAnimationKeyframes()
	if self.version >= 2.0 then
		return -- Seems to have been removed in the RSM2 revamp
	end

	local reader = self.reader
	local numScaleKeyframes = reader:GetInt32()
	for animationFrameID = 1, numScaleKeyframes, 1 do
		local scalingKeyframe = {
			frameID = reader:GetInt32(),
			scale = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
			mysteryBytes = reader:GetFloat(),
		}
		assertEqualNumbers(scalingKeyframe.mysteryBytes, 0, 1E-3)
		table_insert(self.scaleKeyframes, scalingKeyframe)
	end
end

function RagnarokRSM:DecodeOptionalBoundingBoxes()
	local reader = self.reader

	-- It appears that certain 2.3 files end abruptly? Not sure why
	if reader:HasReachedEOF() and self.version == 2.3 then
		return
	end

	local numBoundingBoxes = reader:GetInt32()
	for boxID = 1, numBoundingBoxes, 1 do
		local boundingBox = {
			dimensions = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
			position = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
			rotation = Vector3D(reader:GetFloat(), reader:GetFloat(), reader:GetFloat()),
			unknownFlag = reader:GetInt32(),
		}
		assert(boundingBox.unknownFlag == 0, boundingBox.unknownFlag) -- Unsupported, so fail loudly
		table_insert(self.boundingBoxes, boundingBox)
	end
end

function RagnarokRSM:ToJSON()
	local rsmInfo = {
		signature = self.signature,
		version = self.version,
		animationDurationInMilliseconds = self.animationDurationInMilliseconds,
		shadingModeID = self.shadingModeID,
		opacity = self.opacity,
		animationFPS = self.animationFPS,
		numAnimationFramesPerCycle = self.numAnimationFramesPerCycle,
		mysteryBytes = self.mysteryBytes,
		texturePaths = self.texturePaths,
		rootNodes = self.rootNodes,
		meshes = self.meshes,
		scaleKeyframes = self.scaleKeyframes,
		boundingBoxes = self.boundingBoxes,
	}
	return json.prettier(rsmInfo)
end

return RagnarokRSM
