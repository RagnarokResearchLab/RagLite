local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

describe("RagnarokGRF", function()
	describe("Open", function()
		it("should throw if the given file path does not exist", function()
			local function readNonExistentFile()
				local grf = RagnarokGRF()
				grf:Open("invalid.asdf")
			end
			local expectedErrorMessage = "Failed to open archive invalid.asdf (No such file exists)"
			assertThrows(readNonExistentFile, expectedErrorMessage)
		end)

		it("should throw if the given file path refers to a non-GRF file", function()
			local function readNonExistentFile()
				local grf = RagnarokGRF()
				grf:Open("main.lua") -- Should always exist
			end
			local expectedErrorMessage = "Failed to open archive main.lua (Not a .grf file)"
			assertThrows(readNonExistentFile, expectedErrorMessage)
		end)

		it("should decode the full archive metadata when a valid GRF file path was passed", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:Close()

			assertEquals(grf.signature, RagnarokGRF.MAGIC_HEADER)
			assertEquals(grf.encryptionKey, "")
			assertEquals(grf.fileTableOffsetRelativeToHeader, 384)
			assertEquals(grf.scramblingSeed, 0)
			assertEquals(grf.fileCount, 4)
			assertEquals(grf.version, 2.0)

			assertEquals(grf.fileTable.compressedSizeInBytes, 111)
			assertEquals(grf.fileTable.decompressedSizeInBytes, 134)
			assertEquals(#grf.fileTable.entries, grf.fileCount)

			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].compressedSizeInBytes, 82)
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].byteAlignedSizeInBytes, 88)
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].decompressedSizeInBytes, 78) -- Not a bug; the text file is tiny
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].offsetRelativeToHeader, 0)

			assertEquals(grf.fileTable.entries["hello-grf.txt"].compressedSizeInBytes, 67)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].byteAlignedSizeInBytes, 72)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].decompressedSizeInBytes, 62) -- Not a bug; the text file is tiny
			assertEquals(grf.fileTable.entries["hello-grf.txt"].typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].offsetRelativeToHeader, 88)

			assertEquals(grf.fileTable.entries["uppercase.png"].compressedSizeInBytes, 185) -- Should be normalized/lowercased in RAM
			assertEquals(grf.fileTable.entries["uppercase.png"].byteAlignedSizeInBytes, 192)
			assertEquals(grf.fileTable.entries["uppercase.png"].decompressedSizeInBytes, 189)
			assertEquals(grf.fileTable.entries["uppercase.png"].typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(grf.fileTable.entries["uppercase.png"].offsetRelativeToHeader, 160)
		end)
	end)

	describe("FindLargestFileEntry", function()
		it("should return the largest file name and size when a valid GRF file was opened", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:Close()

			local fileEntry = grf:FindLargestFileEntry()

			assertEquals(fileEntry.name, "uppercase.png")
			assertEquals(fileEntry.compressedSizeInBytes, 185)
			assertEquals(fileEntry.byteAlignedSizeInBytes, 192)
			assertEquals(fileEntry.decompressedSizeInBytes, 189)
			assertEquals(fileEntry.typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(fileEntry.offsetRelativeToHeader, 160)
		end)
	end)

	describe("ExtractFileInMemory", function()
		it("should throw if no entry with the given name exists within the archive", function()
			local function extractWithInvalidPath()
				local grf = RagnarokGRF()
				grf:Open("Tests/Fixtures/test.grf")
				grf:ExtractFileInMemory("invalid.txt")
				grf:Close()
			end
			local expectedErrorMessage = "Failed to extract file invalid.txt (no such entry exists)"
			assertThrows(extractWithInvalidPath, expectedErrorMessage)
		end)

		it("should return the extracted file contents if the path exists within the archive", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local fileContents = grf:ExtractFileInMemory("subdirectory/hello.txt")
			grf:Close()

			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"
			assertEquals(fileContents, expectedFileContents)
		end)

		it("should be tolerant of inconsistent capitalization", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local fileContents = grf:ExtractFileInMemory("subdirectory/HELLO.TXT")
			grf:Close()

			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"
			assertEquals(fileContents, expectedFileContents)
		end)

		it("should be tolerant of inconsistent path separators", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local fileContents = grf:ExtractFileInMemory("subdirectory\\hello.txt")
			grf:Close()

			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"
			assertEquals(fileContents, expectedFileContents)
		end)

		it("should be tolerant of absolute paths", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local fileContents = grf:ExtractFileInMemory("/subdirectory/hello.txt")
			grf:Close()

			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"
			assertEquals(fileContents, expectedFileContents)
		end)
	end)

	describe("ExtractFileToDisk", function()
		it("should throw if no entry with the given name exists within the archive", function()
			local function extractWithInvalidPath()
				local grf = RagnarokGRF()
				grf:Open("Tests/Fixtures/test.grf")
				grf:ExtractFileToDisk("invalid.txt", "hello.txt")
				grf:Close()
			end
			local expectedErrorMessage = "Failed to extract file invalid.txt (no such entry exists)"
			assertThrows(extractWithInvalidPath, expectedErrorMessage)
		end)

		it("should save the extracted file contents to disk if the path exists within the archive", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:ExtractFileToDisk("subdirectory/hello.txt", "hello.txt")
			grf:Close()

			local fileContents = C_FileSystem.ReadFile("hello.txt")
			C_FileSystem.Delete("hello.txt")
			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"

			assertEquals(fileContents, expectedFileContents)
		end)

		it("should be tolerant of inconsistent capitalization", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:ExtractFileToDisk("subdirectory/HELLO.TXT", "hello.txt")
			grf:Close()

			local fileContents = C_FileSystem.ReadFile("hello.txt")
			C_FileSystem.Delete("hello.txt")
			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"

			assertEquals(fileContents, expectedFileContents)
		end)

		it("should be tolerant of inconsistent path separators", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:ExtractFileToDisk("subdirectory\\hello.txt", "hello.txt")
			grf:Close()

			local fileContents = C_FileSystem.ReadFile("hello.txt")
			C_FileSystem.Delete("hello.txt")
			local expectedFileContents =
				"I'm inside the GRF archive, just minding my business. Would you like some tea?"

			assertEquals(fileContents, expectedFileContents)
		end)
	end)

	describe("IsFileEntry", function()
		it("should return false if no entry with the given name exists within the archive", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local isFileEntry = grf:IsFileEntry("invalid.txt")
			grf:Close()
			assertFalse(isFileEntry)
		end)

		it("should return true if an entry with the given name exists within the archive", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local isFileEntry = grf:IsFileEntry("subdirectory/hello.txt")
			grf:Close()
			assertTrue(isFileEntry)
		end)
	end)
end)
