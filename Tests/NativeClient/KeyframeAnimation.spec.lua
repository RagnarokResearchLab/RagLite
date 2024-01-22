local KeyframeAnimation = require("Core.NativeClient.KeyframeAnimation")

describe("KeyframeAnimation", function()
	describe("Construct", function()
		it("should initialize the animation at the first frame", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.currentAnimationFrame, 0)
		end)

		it("should set the animation length if one was passed", function()
			local animation = KeyframeAnimation(42)
			assertEquals(animation.numAnimationFrames, 42)
		end)

		it("should set the animation length to one frame if none was passed", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.numAnimationFrames, 1)
		end)

		it("should initialize the animation with no accumulated delta time", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)
		end)

		it("should initialize the animation with a speed of 1 texture swap per frame at 60 FPS", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)
			local MILLISECONDS_PER_SECOND = 1000
			local TARGET_FPS = 60

			local expectedNumFramesPerTexture = 3
			local expectedSecondsPerFrame = expectedNumFramesPerTexture / TARGET_FPS
			assertEquals(
				animation.frameDisplayDurationInMilliseconds,
				expectedSecondsPerFrame * MILLISECONDS_PER_SECOND
			)
		end)
	end)

	describe("UpdateWithDeltaTime", function()
		it("should not advance the animation if the delta time is below the set frame duration", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)

			animation.frameDisplayDurationInMilliseconds = 1000 -- Something large
			animation:UpdateWithDeltaTime(50) -- Something smaller

			assertEquals(animation.currentAnimationFrame, 0)
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 50)
		end)

		it("should advance the animation if the delta time is equal to the set frame duration", function()
			local animation = KeyframeAnimation(2) -- Needs to have more than one frame to advance
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)
			assertEquals(animation.currentAnimationFrame, 0)

			animation.frameDisplayDurationInMilliseconds = 1000 -- Something large
			animation:UpdateWithDeltaTime(1000) -- The same value

			assertEquals(animation.currentAnimationFrame, 1)
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)
		end)

		it("should advance the animation if the delta time is larger than the set frame duration", function()
			local animation = KeyframeAnimation(5) -- Needs to have frames to advance to
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)

			animation.frameDisplayDurationInMilliseconds = 1000 -- Something large

			animation:UpdateWithDeltaTime(1500) -- Larger, but not a whole new frame
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 500)
			assertEquals(animation.currentAnimationFrame, 1) -- Should actually have advanced 1.5 frames

			animation:UpdateWithDeltaTime(1500)
			assertEquals(animation.currentAnimationFrame, 3) -- Should have advanced 1.5 more frames
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)
		end)

		it("should accumulate the delta time if it is below the set frame duration", function()
			local animation = KeyframeAnimation()
			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 0)

			animation.frameDisplayDurationInMilliseconds = 1000 -- Something large
			animation:UpdateWithDeltaTime(100) -- Not enough time to advance to the next frame

			assertEquals(animation.accumulatedDeltaTimeInMilliseconds, 100)
		end)

		it("should do nothing if the frame duration is zero", function()
			-- Regression: Static animations might have only one frame and no frame duration; these shouldn't be updated at all
			-- Not doing this leads to a "divided by zero" error and the current frame will become invalid, and the animation breaks
			local animation = KeyframeAnimation()

			animation.frameDisplayDurationInMilliseconds = 0
			assertEquals(animation.currentAnimationFrame, 0)

			animation:UpdateWithDeltaTime(100)
			assertEquals(animation.currentAnimationFrame, 0)

			animation:UpdateWithDeltaTime(10000)
			assertEquals(animation.currentAnimationFrame, 0)

			animation:UpdateWithDeltaTime(10000000)
			assertEquals(animation.currentAnimationFrame, 0)
		end)
	end)
end)
