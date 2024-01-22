local KeyframeAnimation = {}

function KeyframeAnimation:Construct(numAnimationFrames)
	numAnimationFrames = numAnimationFrames or 1

	local instance = {
		currentAnimationFrame = 1,
		accumulatedDeltaTimeInMilliseconds = 0,
		frameDisplayDurationInMilliseconds = 50, -- 3 frames at 16.67 ms per frame
		numAnimationFrames = numAnimationFrames,
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function KeyframeAnimation:UpdateWithDeltaTime(deltaTime)
	self.accumulatedDeltaTimeInMilliseconds = self.accumulatedDeltaTimeInMilliseconds + deltaTime

	-- Static animations can't be updated
	if self.frameDisplayDurationInMilliseconds == 0 then
		return
	end

	local numFramesToAdvance =
		math.floor(self.accumulatedDeltaTimeInMilliseconds / self.frameDisplayDurationInMilliseconds)
	self.currentAnimationFrame = self.currentAnimationFrame + numFramesToAdvance

	-- Can't advance frames partially since animation frames are always integers
	self.currentAnimationFrame = (self.currentAnimationFrame - 1) % self.numAnimationFrames + 1
	self.accumulatedDeltaTimeInMilliseconds = self.accumulatedDeltaTimeInMilliseconds
		- (numFramesToAdvance * self.frameDisplayDurationInMilliseconds)
end

class("KeyframeAnimation", KeyframeAnimation)

return KeyframeAnimation
