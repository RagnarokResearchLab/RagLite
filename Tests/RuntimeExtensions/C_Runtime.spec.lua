describe("C_Runtime", function()
	describe("IsTesting", function()
		it("should return true while the test runner is active", function()
			assertTrue(C_Runtime.IsTesting())
		end)
	end)
end)
