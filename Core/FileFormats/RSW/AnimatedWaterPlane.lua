local AnimatedWaterPlane = {
	TEXTURE_ANIMATION_SPEED_IN_FRAMES_PER_SECOND = 60,
	NUM_FRAMES_PER_TEXTURE_ANIMATION = 32, -- Highest possible frame ID
}

function AnimatedWaterPlane:Construct(defaults)
	local instance = {
		normalizedSeaLevel = defaults.normalizedSeaLevel or 0,
		textureTypePrefix = defaults.textureTypePrefix or 1,
		waveformAmplitudeScalingFactor = defaults.waveformAmplitudeScalingFactor or 1,
		waveformPhaseShiftInDegreesPerFrame = defaults.waveformPhaseShiftInDegreesPerFrame or 2,
		waveformFrequencyInDegrees = defaults.waveformFrequencyInDegrees or 50,
		textureDisplayDurationInFrames = defaults.textureDisplayDurationInFrames or 3,
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

AnimatedWaterPlane.__call = AnimatedWaterPlane.Construct
AnimatedWaterPlane.__index = AnimatedWaterPlane
setmetatable(AnimatedWaterPlane, AnimatedWaterPlane)

return AnimatedWaterPlane
