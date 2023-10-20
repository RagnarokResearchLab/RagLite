local RagnarokRGZ = require("Core.FileFormats.RagnarokRGZ")

local RGZ_TEST_FILE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "test.rgz"))

describe("RagnarokRGZ", function()
	describe("DecodeFileContents", function()
		it("should be able to decode a valid RGZ archive", function()
			local rgz = RagnarokRGZ()
			rgz:DecodeFileContents(RGZ_TEST_FILE)

			assertEquals(rgz.entries, {
				{
					data = "",
					name = "subdirectory",
					size = 0,
					type = "d",
				},
				{
					data = "I'm inside the GRF archive, just minding my business. Would you like some tea?",
					name = "subdirectory\\hello.txt",
					size = 78,
					type = "f",
				},
				{
					data = "I'm at the top level of the GRF archive. How did you get here?",
					name = "hello-grf.txt",
					size = 62,
					type = "f",
				},
				{
					data = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "UPPERCASE.PNG")),
					name = "UPPERCASE.PNG",
					size = 189,
					type = "f",
				},
				{
					data = "안녕하십니까",
					name = "안녕하세요.txt",
					size = 18,
					type = "f",
				},
				{
					data = "",
					name = "end",
					size = 0,
					type = "e",
				},
			})
		end)
	end)
end)
