local AssetServer = require("Core.AssetServer")

describe("AssetServer", function()
	describe("GetContentType", function()
		it("should default to octet-stream if no entry exists in the server's lookup table", function()
			local mimeType = AssetServer:GetContentType("test.foo")
			assertEquals(mimeType, "application/octet-stream")
		end)

		it("should return the correct MIME type for all supported file extensions", function()
			local supportedFileExtensions = {
				[".js"] = "text/javascript",
				[".css"] = "text/css",
				[".htm"] = "text/html",
				[".html"] = "text/html",
				[".wav"] = "audio/wav",
				[".mp3"] = "audio/mpeg",
				[".ogg"] = "audio/ogg",
				[".png"] = "image/png",
				[".jpg"] = "image/jpeg",
				[".bmp"] = "image/bmp",
				[".json"] = "application/json",
			}

			for extension, expectedContentType in pairs(supportedFileExtensions) do
				local mimeType = AssetServer:GetContentType("test" .. extension)
				assertEquals(mimeType, expectedContentType)
			end
		end)

		it("should return the correct MIME type regardless of the capitalization used", function()
			assertEquals(AssetServer:GetContentType("test.htm"), AssetServer:GetContentType("test.HTML"))
			assertEquals(AssetServer:GetContentType("test.htm"), AssetServer:GetContentType("test.htML"))
		end)
	end)
end)
