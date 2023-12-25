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
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].alignedSizeInBytes, 88)
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].decompressedSizeInBytes, 78) -- Not a bug; the text file is tiny
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(grf.fileTable.entries["subdirectory/hello.txt"].offsetRelativeToHeader, 0)

			assertEquals(grf.fileTable.entries["hello-grf.txt"].compressedSizeInBytes, 67)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].alignedSizeInBytes, 72)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].decompressedSizeInBytes, 62) -- Not a bug; the text file is tiny
			assertEquals(grf.fileTable.entries["hello-grf.txt"].typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(grf.fileTable.entries["hello-grf.txt"].offsetRelativeToHeader, 88)

			assertEquals(grf.fileTable.entries["uppercase.png"].compressedSizeInBytes, 185) -- Should be normalized/lowercased in RAM
			assertEquals(grf.fileTable.entries["uppercase.png"].alignedSizeInBytes, 192)
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
			assertEquals(fileEntry.alignedSizeInBytes, 192)
			assertEquals(fileEntry.decompressedSizeInBytes, 189)
			assertEquals(fileEntry.typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(fileEntry.offsetRelativeToHeader, 160)
		end)
	end)

	describe("FindFilesByType", function()
		local grf = RagnarokGRF()
		grf:Open("Tests/Fixtures/test.grf")
		grf:Close()

		it("should return a list of files of the given type when a valid GRF file was opened", function()
			local fileEntries = grf:FindFilesByType(".png")
			assertEquals(#fileEntries, 1)
			local fileEntry = fileEntries[1]
			assertEquals(fileEntry.name, "uppercase.png")
			assertEquals(fileEntry.compressedSizeInBytes, 185)
			assertEquals(fileEntry.alignedSizeInBytes, 192)
			assertEquals(fileEntry.decompressedSizeInBytes, 189)
			assertEquals(fileEntry.typeID, RagnarokGRF.COMPRESSED_FILE_ENTRY_TYPE)
			assertEquals(fileEntry.offsetRelativeToHeader, 160)
		end)

		it("should automatically add a leading dot if one isn't already part of the given file extension", function()
			local fileEntries = grf:FindFilesByType("png")
			assertEquals(#fileEntries, 1)
			local fileEntry = fileEntries[1]
			assertEquals(fileEntry.name, "uppercase.png")
			assertEquals(fileEntry.compressedSizeInBytes, 185)
			assertEquals(fileEntry.alignedSizeInBytes, 192)
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

		it("should throw if no file handle has been opened yet", function()
			local function extractBeforeOpen()
				local grf = RagnarokGRF()
				grf:ExtractFileInMemory("something.txt")
			end
			local expectedErrorMessage =
				"Failed to extract something.txt (no file table loaded; forgot to open a handle?)"
			assertThrows(extractBeforeOpen, expectedErrorMessage)
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

		it("should accept normalized path names", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:ExtractFileToDisk("안녕하세요.txt", "안녕하세요.txt")
			grf:Close()

			local fileContents = C_FileSystem.ReadFile("안녕하세요.txt")
			C_FileSystem.Delete("안녕하세요.txt")
			local expectedFileContents = "안녕하십니까"

			assertEquals(fileContents, expectedFileContents)
		end)

		it("should throw if no file handle has been opened yet", function()
			local function extractBeforeOpen()
				local grf = RagnarokGRF()
				grf:ExtractFileToDisk("something.txt", "whatever")
			end
			local expectedErrorMessage =
				"Failed to extract something.txt (no file table loaded; forgot to open a handle?)"
			assertThrows(extractBeforeOpen, expectedErrorMessage)
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

		it("should accept normalized path names", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			local isFileEntry = grf:IsFileEntry("안녕하세요.txt")
			grf:Close()
			assertTrue(isFileEntry)
		end)
	end)

	describe("GetFileList", function()
		it("should return the decoded file list", function()
			local grf = RagnarokGRF()
			grf:Open("Tests/Fixtures/test.grf")
			grf:Close()
			local fileList = grf:GetFileList()

			assertEquals(fileList["hello-grf.txt"].name, "hello-grf.txt")
			assertEquals(fileList["subdirectory/hello.txt"].name, "subdirectory/hello.txt")
			assertEquals(fileList["uppercase.png"].name, "uppercase.png")
			assertEquals(fileList["안녕하세요.txt"].name, "안녕하세요.txt")
		end)
	end)

	describe("GetNormalizedFilePath", function()
		it("should convert upper-case to lower-case characters", function()
			assertEquals(RagnarokGRF:GetNormalizedFilePath("TEST.BMP"), "test.bmp")
		end)

		it("should remove leading path separators", function()
			-- These are added by the HTTP route handler, but they're useless for path lookups
			assertEquals(RagnarokGRF:GetNormalizedFilePath("/hello/world.txt"), "hello/world.txt")
		end)

		it("should replace Windows path separators with POSIX ones", function()
			assertEquals(RagnarokGRF:GetNormalizedFilePath("hello\\world.txt"), "hello/world.txt")
		end)

		it("should remove duplicate path separators", function()
			assertEquals(RagnarokGRF:GetNormalizedFilePath("hello\\\\world.txt"), "hello/world.txt")
		end)
	end)

	describe("DecodeFileName", function()
		it("should convert EUC-KR names to UTF8", function()
			assertEquals(
				RagnarokGRF:DecodeFileName("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA.txt"),
				"유저인터페이스.txt"
			)

			local inputString = "\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA.txt\0"
			local inputBuffer = buffer.new():put(inputString)
			local pointerToNullTerminatedStringBytes = inputBuffer:ref()
			assertEquals(RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes), "유저인터페이스.txt")
		end)

		it("should convert upper-case to lower-case characters", function()
			assertEquals(RagnarokGRF:DecodeFileName("TEST.BMP"), "test.bmp")

			local inputString = "TEST.BMP\0"
			local inputBuffer = buffer.new():put(inputString)
			local pointerToNullTerminatedStringBytes = inputBuffer:ref()
			assertEquals(RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes), "test.bmp")
		end)

		it("should remove leading path separators", function()
			-- These are added by the HTTP route handler, but they're useless for path lookups
			assertEquals(RagnarokGRF:DecodeFileName("/hello/world.txt"), "hello/world.txt")

			local inputString = "/hello/world.txt\0"
			local inputBuffer = buffer.new():put(inputString)
			local pointerToNullTerminatedStringBytes = inputBuffer:ref()
			assertEquals(RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes), "hello/world.txt")
		end)

		it("should replace Windows path separators with POSIX ones", function()
			assertEquals(RagnarokGRF:DecodeFileName("hello\\world.txt"), "hello/world.txt")

			local inputString = "hello\\world.txt\0"
			local inputBuffer = buffer.new():put(inputString)
			local pointerToNullTerminatedStringBytes = inputBuffer:ref()
			assertEquals(RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes), "hello/world.txt")
		end)

		it("should remove duplicate path separators", function()
			assertEquals(RagnarokGRF:DecodeFileName("hello\\\\world.txt"), "hello/world.txt")

			local inputString = "hello\\\\world.txt\0"
			local inputBuffer = buffer.new():put(inputString)
			local pointerToNullTerminatedStringBytes = inputBuffer:ref()
			assertEquals(RagnarokGRF:DecodeFileName(pointerToNullTerminatedStringBytes), "hello/world.txt")
		end)
	end)
end)
