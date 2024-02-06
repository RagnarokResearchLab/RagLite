local CompiledGRF = require("Core.FileFormats.Optimized.CompiledGRF")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local C_Resources = require("Core.NativeClient.C_Resources")

local TEST_GRF_PATH = path.join("Tests", "Fixtures", "test.grf")

describe("C_Resources", function()
	describe("PreloadPersistentResources", function()
		local DEFAULT_GRF_PATH = C_Resources.GRF_FILE_PATH
		local PRELOADED_ASSET_FILES = C_Resources.PERSISTENT_RESOURCES

		after(function()
			C_Resources.GRF_FILE_PATH = DEFAULT_GRF_PATH
			C_Resources.PERSISTENT_RESOURCES = PRELOADED_ASSET_FILES
		end)

		it("should throw if the configured asset container doesn't exist", function()
			local function preloadFromNonExistingGRF()
				C_Resources.ENABLE_CGRF_CACHING = false -- Cache access would throw
				C_Resources.GRF_FILE_PATH = "invalid.grf"
				C_Resources.PreloadPersistentResources()
			end
			local expectedErrorMessage = "Failed to open archive invalid.grf (No such file exists)"
			assertThrows(preloadFromNonExistingGRF, expectedErrorMessage)
		end)

		it("should throw if the configured asset container isn't a valid GRF archive", function()
			local SOME_EXISTING_FILE = path.join("Tests", "Fixtures", "test.rgz")
			local function preloadFromInvalidGRF()
				C_Resources.GRF_FILE_PATH = SOME_EXISTING_FILE
				C_Resources.PreloadPersistentResources()
			end
			local expectedErrorMessage = format("Failed to open archive %s (Not a .grf file)", SOME_EXISTING_FILE)
			assertThrows(preloadFromInvalidGRF, expectedErrorMessage)
		end)

		it("should load and store all persistent resources from the configured asset container", function()
			C_Resources.GRF_FILE_PATH = TEST_GRF_PATH
			C_Resources.PERSISTENT_RESOURCES = {
				["hello-grf.txt"] = false,
				["subdirectory/hello.txt"] = false,
				["uppercase.png"] = false,
				["안녕하세요.txt"] = false,
			}
			C_Resources.PreloadPersistentResources()

			local grf = RagnarokGRF()
			grf:Open(C_Resources.GRF_FILE_PATH)
			local expectedFileContents = {
				["hello-grf.txt"] = grf:ExtractFileInMemory("hello-grf.txt"),
				["subdirectory/hello.txt"] = grf:ExtractFileInMemory("subdirectory/hello.txt"),
				["uppercase.png"] = grf:ExtractFileInMemory("uppercase.png"),
				["안녕하세요.txt"] = grf:ExtractFileInMemory("안녕하세요.txt"),
			}
			grf:Close()

			-- Might want to add metadata later, but for now just caching the file contents should suffice
			local preloadedAssetFiles = C_Resources.PERSISTENT_RESOURCES
			assertEquals(preloadedAssetFiles["hello-grf.txt"], expectedFileContents["hello-grf.txt"])
			assertEquals(preloadedAssetFiles["subdirectory/hello.txt"], expectedFileContents["subdirectory/hello.txt"])
			assertEquals(preloadedAssetFiles["uppercase.png"], expectedFileContents["uppercase.png"])
			assertEquals(preloadedAssetFiles["안녕하세요.txt"], expectedFileContents["안녕하세요.txt"])
		end)

		it("should decode any persistent resources that have been assigned a decoder", function()
			C_Resources.GRF_FILE_PATH = path.join("Tests", "Fixtures", "test.grf")

			-- This needs some streamlining once a proper resource management API is implemented
			local MakeshiftImageDecoder = {
				DecodeFileContents = function(self, fileContents)
					local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(fileContents)
					local imageResource = {
						width = width,
						height = height,
						rgbaImageBytes = rgbaImageBytes,
					}
					return imageResource
				end,
			}

			C_Resources.PERSISTENT_RESOURCES = {
				["uppercase.png"] = MakeshiftImageDecoder,
			}
			C_Resources.PreloadPersistentResources()

			local grf = RagnarokGRF()
			grf:Open(C_Resources.GRF_FILE_PATH)

			local rgbaImageBytes, width, height =
				C_ImageProcessing.DecodeFileContents(grf:ExtractFileInMemory("uppercase.png"))
			local expectedFileContents = {
				["uppercase.png"] = {
					rgbaImageBytes = rgbaImageBytes,
					width = width,
					height = height,
				},
			}
			grf:Close()

			-- Might want to add metadata later, but for now just caching the file contents should suffice
			local preloadedAssetFiles = C_Resources.PERSISTENT_RESOURCES
			assertEquals(preloadedAssetFiles["uppercase.png"], expectedFileContents["uppercase.png"])
		end)

		it("should generate a CGRF cache entry after loading the configured asset container", function()
			C_Resources.ENABLE_CGRF_CACHING = true
			C_Resources.GRF_FILE_PATH = TEST_GRF_PATH
			C_Resources.PERSISTENT_RESOURCES = {}
			C_Resources.PreloadPersistentResources()

			local cgrfFilePath = path.join("Tests", "Fixtures", "test.cgrf")
			local expectedFileContents = C_FileSystem.ReadFile(cgrfFilePath)

			-- Creating a new cache entry manually should ensure it's considered up-to-date
			local cacheEntryPath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, "test.cgrf")
			local cgrfFileContents = C_FileSystem.ReadFile(cacheEntryPath)

			C_FileSystem.Delete(cacheEntryPath)

			assertEquals(cgrfFileContents, expectedFileContents)
		end)

		it("should use an existing CGRF cache entry if it exists and is still up-to-date", function()
			-- Assumes that the fixture's CGRF is always more recent than the GRF itself
			-- This should always be the case as it's regenerated from the GRF after each format change
			local cgrfFilePath = path.join("Tests", "Fixtures", "test.cgrf")
			local cgrfFileContents = C_FileSystem.ReadFile(cgrfFilePath)

			-- Creating a new cache entry manually should ensure it's considered up-to-date
			local cacheEntryPath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, "test.cgrf")
			C_FileSystem.WriteFile(cacheEntryPath, cgrfFileContents)

			C_Resources.ENABLE_CGRF_CACHING = true
			C_Resources.GRF_FILE_PATH = TEST_GRF_PATH
			C_Resources.PERSISTENT_RESOURCES = {}
			C_Resources.PreloadPersistentResources()

			C_FileSystem.Delete(cacheEntryPath)

			assertEquals(C_Resources.grf.fileTable.compressedSizeInBytes, 0)
			assertEquals(C_Resources.grf.fileTable.decompressedSizeInBytes, 0)
		end)
	end)
end)
