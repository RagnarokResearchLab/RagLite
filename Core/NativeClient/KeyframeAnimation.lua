local uuid = require("uuid")

local KeyframeAnimation = {
	LOOP_MODE_REPEAT = "REPEAT",
	PLAYBACK_DIRECTION_FORWARD = "FORWARD",
	INTERPOLATION_MODE_NONE = "NONE",
}

function KeyframeAnimation:Construct(name, framesPerSecond)
	local instance = {
		displayName = name or uuid.create(),
		keyframes = {},
		-- playbackState = {
			isPlaying = false, --isEnabled = false,
			currentFrame = 0, -- currentFrameIndex = 0,
			elapsedTimeInMilliseconds = 0,
			-- },
			-- playbackMode = {
				framesPerSecond = framesPerSecond or 60,
				loopMode = KeyframeAnimation.LOOP_MODE_REPEAT,
				direction = KeyframeAnimation.PLAYBACK_DIRECTION_FORWARD,
				interpolationMode = KeyframeAnimation.INTERPOLATION_MODE_NONE,
			-- }
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function KeyframeAnimation:UpdateWithDeltaTime(deltaTimeInMilliseconds)
	if not self.isPlaying then return end
end
function KeyframeAnimation:Start()
	self.isPlaying = true
end

function KeyframeAnimation:Stop()
	self.isPlaying = false
	self.currentFrame = 0
	self.elapsedTimeInMilliseconds = 0
end

class("KeyframeAnimation", KeyframeAnimation)

return KeyframeAnimation
