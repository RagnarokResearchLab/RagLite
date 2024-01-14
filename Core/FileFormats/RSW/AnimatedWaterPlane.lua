require("table.new")

local math_ceil = math.ceil
local math_min = math.min

local AnimatedWaterPlane = {
	TEXTURE_ANIMATION_SPEED_IN_FRAMES_PER_SECOND = 60,
	NUM_FRAMES_PER_TEXTURE_ANIMATION = 32, -- Highest possible frame ID
}
function AnimatedWaterPlane:Construct(tileSlotU, tileSlotV, surfaceProperties)
	surfaceProperties = surfaceProperties or {}

	local instance = {
		surfaceRegion = {
			tileSlotU = tileSlotU,
			tileSlotV = tileSlotV,
			minU = 0,
			minV = 0,
			maxU = 0,
			maxV = 0,
		},
		normalizedSeaLevel = surfaceProperties.normalizedSeaLevel or 0,
		textureTypePrefix = surfaceProperties.textureTypePrefix or 1,
		waveformAmplitudeScalingFactor = surfaceProperties.waveformAmplitudeScalingFactor or 1,
		waveformPhaseShiftInDegreesPerFrame = surfaceProperties.waveformPhaseShiftInDegreesPerFrame or 2,
		waveformFrequencyInDegrees = surfaceProperties.waveformFrequencyInDegrees or 50,
		textureDisplayDurationInFrames = surfaceProperties.textureDisplayDurationInFrames or 3,
	}

	setmetatable(instance, self)

	return instance
end

-- Normalizing timings serves to decouple animation speed from the actual frame rate
function AnimatedWaterPlane:GetTextureAnimationDuration(textureDisplayDurationInFrames)
	local framesPerAnimationCycle = textureDisplayDurationInFrames * self.NUM_FRAMES_PER_TEXTURE_ANIMATION
	local normalizedCycleTimeInSeconds = framesPerAnimationCycle / self.TEXTURE_ANIMATION_SPEED_IN_FRAMES_PER_SECOND
	local normalizedCycleTimeInMilliseconds = normalizedCycleTimeInSeconds * 1000
	return normalizedCycleTimeInMilliseconds
end

function AnimatedWaterPlane:AlignWithGroundMesh(gnd)
	local waterSegmentSizeU = math_ceil(gnd.gridSizeU / gnd.numWaterPlanesU)
	local waterSegmentSizeV = math_ceil(gnd.gridSizeV / gnd.numWaterPlanesV)

	self.surfaceRegion.minU = (self.surfaceRegion.tileSlotU - 1) * waterSegmentSizeU + 1
	self.surfaceRegion.minV = (self.surfaceRegion.tileSlotV - 1) * waterSegmentSizeV + 1
	self.surfaceRegion.maxU = (self.surfaceRegion.tileSlotU - 0) * waterSegmentSizeU + 1
	self.surfaceRegion.maxV = (self.surfaceRegion.tileSlotV - 0) * waterSegmentSizeV + 1

	-- Uneven tile sizes may lead to rounding errors accumulating enough to reach OOB coordinates
	self.surfaceRegion.maxU = math_min(self.surfaceRegion.maxU, gnd.gridSizeU)
	self.surfaceRegion.maxV = math_min(self.surfaceRegion.maxV, gnd.gridSizeV)
end

AnimatedWaterPlane.__call = AnimatedWaterPlane.Construct
AnimatedWaterPlane.__index = AnimatedWaterPlane
setmetatable(AnimatedWaterPlane, AnimatedWaterPlane)

return AnimatedWaterPlane
