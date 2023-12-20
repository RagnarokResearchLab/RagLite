local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokMap = require("Core.FileFormats.RagnarokMap")

local function makeFileSystem(name)
	local testFileSystem = {
		ROOT_DIR = path.join("Tests", "Fixtures", "Borftopia"),
		name = name,
	}

	function testFileSystem.Fetch(fileSystem, resourceID)
		local resourcePath = path.join(fileSystem.ROOT_DIR, resourceID)
		printf("Fetching resource %s via %s", resourcePath, fileSystem.name)
		return C_FileSystem.ReadFile(resourcePath)
	end

	return testFileSystem
end
local testFileSystem = makeFileSystem("C_FileSystem")

-- Should probably avoid loading all these, but that can wait until after the Resources API is in
local gndBytes = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "borftopia.gnd"))
local gnd = RagnarokGND()
gnd:DecodeFileContents(gndBytes)
local groundMeshSections = gnd:GenerateGroundMeshSections()

local gradientTextureBytes =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "texture", "texture1.bmp"))
local gridTextureBytes =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "texture", "somedir1", "texture2-01.bmp"))
local gradientTexture = C_ImageProcessing.DecodeFileContents(gradientTextureBytes)
local gridTexture = C_ImageProcessing.DecodeFileContents(gridTextureBytes)

describe("RagnarokMap", function()
	describe("Construct", function()
		it("should fail if an invalid map ID was passed", function()
			assertFailure(function()
				return RagnarokMap("cube3d")
			end, RagnarokMap.ERROR_INVALID_MAP_ID)
		end)

		it("should throw if no file system handler was provided", function()
			assertThrows(function()
				RagnarokMap("aldebaran", nil)
			end, RagnarokMap.ERROR_INVALID_FILE_SYSTEM)
		end)

		it("should return the complete scene definition if a valid map ID was passed", function()
			local backupDB = RagnarokMap.MAP_DATABASE
			RagnarokMap.MAP_DATABASE = {
				borftopia = {
					displayName = "Borftopia",
				},
			}
			local map = RagnarokMap("borftopia", testFileSystem)
			RagnarokMap.MAP_DATABASE = backupDB
			assertEquals(map.mapID, "borftopia")
			assertEquals(map.displayName, "Borftopia")
			assertEquals(#map.meshes, 2)
			assertEquals(#map.meshes, #groundMeshSections)

			assertEquals(map.meshes[1].diffuseTexture.rgbaImageBytes, gradientTexture)
			assertEquals(map.meshes[1].diffuseTexture.width, 256)
			assertEquals(map.meshes[1].diffuseTexture.height, 256)
			assertEquals(map.meshes[1].vertexPositions, groundMeshSections[1].vertexPositions)
			assertEquals(map.meshes[1].vertexColors, groundMeshSections[1].vertexColors)
			assertEquals(map.meshes[1].triangleConnections, groundMeshSections[1].triangleConnections)
			assertEquals(map.meshes[1].diffuseTextureCoords, groundMeshSections[1].diffuseTextureCoords)

			assertEquals(map.meshes[2].diffuseTexture.rgbaImageBytes, gridTexture)
			assertEquals(map.meshes[2].diffuseTexture.width, 256)
			assertEquals(map.meshes[2].diffuseTexture.height, 256)
			assertEquals(map.meshes[2].vertexPositions, groundMeshSections[2].vertexPositions)
			assertEquals(map.meshes[2].vertexColors, groundMeshSections[2].vertexColors)
			assertEquals(map.meshes[2].triangleConnections, groundMeshSections[2].triangleConnections)
			assertEquals(map.meshes[2].diffuseTextureCoords, groundMeshSections[2].diffuseTextureCoords)
		end)

		it("should set a default display name if the given map ID wasn't assigned one in the DB", function()
			local backupDB = RagnarokMap.MAP_DATABASE
			RagnarokMap.MAP_DATABASE = { borftopia = {
				displayName = nil,
			} }
			local map = RagnarokMap("borftopia", testFileSystem)
			RagnarokMap.MAP_DATABASE = backupDB
			assertEquals(map.displayName, "Unknown")
		end)
	end)
end)