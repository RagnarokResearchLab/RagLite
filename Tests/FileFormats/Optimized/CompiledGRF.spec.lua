local CompiledGRF = require("Core.FileFormats.Optimized.CompiledGRF")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local uv = require("uv")

local TEST_GRF_PATH = path.join("Tests", "Fixtures", "test.grf")

describe("CompiledGRF", function()
	describe("IsCacheUpdated", function()
		it("should throw if no GRF file path was provided", function()
			local expectedErrorMessage =
				"Expected argument grfFilePath to be a string value, but received a nil value instead"
			assertThrows(function()
				CompiledGRF:IsCacheUpdated(nil)
			end, expectedErrorMessage)
		end)

		it("should throw if no GRF with the provided file path exists", function()
			assertThrows(function()
				CompiledGRF:IsCacheUpdated("does-not-exist.grf")
			end, format(CompiledGRF.errorStrings.INVALID_GRF_PATH, "does-not-exist.grf"))
		end)

		it("should throw if the provided file path is not referencing a GRF file", function()
			assertThrows(function()
				CompiledGRF:IsCacheUpdated("README.md")
			end, format(CompiledGRF.errorStrings.INVALID_GRF_PATH, "README.md"))
		end)

		it("should return false if no CGRF entry exists for the provided GRF", function()
			local cgrfFilePath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, "test.cgrf")
			C_FileSystem.Delete(cgrfFilePath)

			assertFalse(CompiledGRF:IsCacheUpdated(TEST_GRF_PATH))
		end)

		it("should return false if the provided GRF is more recent than the cached CGRF", function()
			local cgrfFilePath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, "test.cgrf")
			C_FileSystem.Delete(cgrfFilePath)

			C_FileSystem.WriteFile(cgrfFilePath, "") -- File contents shouldn't be relevant for mtime detection
			assert(uv.fs_utime(cgrfFilePath, 1, 1)) -- Set modified date to January 1st, 1970

			assertFalse(CompiledGRF:IsCacheUpdated(TEST_GRF_PATH))

			C_FileSystem.Delete(cgrfFilePath)
		end)

		it("should return true if the cached CGRF is more recent than the provided GRF", function()
			local cgrfFilePath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, "test.cgrf")
			C_FileSystem.Delete(cgrfFilePath)

			C_FileSystem.WriteFile(cgrfFilePath, "") -- File contents shouldn't be relevant for mtime detection

			local fileAttributes, errorMessage = uv.fs_stat(cgrfFilePath)
			assert(fileAttributes, errorMessage)
			assert(uv.fs_utime(cgrfFilePath, 1, fileAttributes.mtime.sec + 1))

			assertTrue(CompiledGRF:IsCacheUpdated(TEST_GRF_PATH))

			C_FileSystem.Delete(cgrfFilePath)
		end)

		it("should create the CGRF cache directory if it doesn't yet exist", function()
			local cacheDirectory = "DoesNotExistProbably"
			local originalCacheDirectory = CompiledGRF.CGRF_CACHE_DIRECTORY

			C_FileSystem.Delete(cacheDirectory)
			assertFalse(C_FileSystem.Exists(cacheDirectory))
			assertFalse(C_FileSystem.IsDirectory(cacheDirectory))

			CompiledGRF.CGRF_CACHE_DIRECTORY = cacheDirectory
			CompiledGRF:IsCacheUpdated(TEST_GRF_PATH)
			CompiledGRF.CGRF_CACHE_DIRECTORY = originalCacheDirectory

			assertTrue(C_FileSystem.Exists(cacheDirectory))
			assertTrue(C_FileSystem.IsDirectory(cacheDirectory))

			C_FileSystem.Delete(cacheDirectory)
		end)
	end)

	describe("CompileTableOfContents", function()
		it("should generate a CGRF buffer storing the provided GRF instance's file table", function()
			local grf = RagnarokGRF()
			grf:Open(TEST_GRF_PATH)
			grf:Close()

			local cgrfFileContents = CompiledGRF:CompileTableOfContents(grf)

			local cgrfFilePath = path.join("Tests", "Fixtures", "test.cgrf")
			local expectedFileContents = C_FileSystem.ReadFile(cgrfFilePath)
			assertEquals(cgrfFileContents, expectedFileContents)
		end)
	end)

	describe("RestoreTableOfContents", function()
		it("should restore the provided GRF instance's file table from the CGRF buffer", function()
			local grf = RagnarokGRF()
			grf:Open(TEST_GRF_PATH)
			grf:Close()
			local expectedFileEntries = grf.fileTable.entries

			local unOpenedGRF = RagnarokGRF()

			local cgrfFilePath = path.join("Tests", "Fixtures", "test.cgrf")
			local cgrfBuffer = C_FileSystem.ReadFile(cgrfFilePath)

			CompiledGRF:RestoreTableOfContents(unOpenedGRF, cgrfBuffer)

			assertEquals(#unOpenedGRF.fileTable.entries, #expectedFileEntries)
			assertEquals(#unOpenedGRF.fileTable.entries, 4)
			assertEquals(unOpenedGRF.fileTable.compressedSizeInBytes, 0)
			assertEquals(unOpenedGRF.fileTable.decompressedSizeInBytes, 0)
			assertEquals(unOpenedGRF.fileTable.entries[1], expectedFileEntries[1])
			assertEquals(unOpenedGRF.fileTable.entries[2], expectedFileEntries[2])
			assertEquals(unOpenedGRF.fileTable.entries[3], expectedFileEntries[3])
			assertEquals(unOpenedGRF.fileTable.entries[4], expectedFileEntries[4])
		end)
	end)
end)
