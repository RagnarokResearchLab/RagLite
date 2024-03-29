local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokMap = require("Core.FileFormats.RagnarokMap")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")

local Texture = require("Core.NativeClient.WebGPU.Texture")

local openssl = require("openssl")
local digest = openssl.digest.digest

local function assertImageChecksumMatches(actualImageBytes, expectedImageBytes)
	local checksum = digest("sha256", tostring(actualImageBytes))
	expectedImageBytes = Texture:CreateReducedColorImage(expectedImageBytes, 256, 256)
	local expectedChecksum = digest("sha256", tostring(expectedImageBytes))
	assertEquals(checksum, expectedChecksum)
end

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

local rswBytes = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "borftopia.rsw"))
local rsw = RagnarokRSW()
rsw:DecodeFileContents(rswBytes)
local waterPlanes = rsw.waterPlanes

local gradientTextureBytes =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "texture", "texture1.bmp"))
local gridTextureBytes =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Borftopia", "texture", "somedir1", "texture2-01.bmp"))
local gradientTexture = C_ImageProcessing.DecodeFileContents(gradientTextureBytes)
local gridTexture = C_ImageProcessing.DecodeFileContents(gridTextureBytes)

-- This should be replaced with a better solution; maybe preload via resource cache once that's in?
local blankImageBuffer = Texture:GenerateBlankImage()
local blankImage = tostring(buffer.new():putcdata(blankImageBuffer, 256 * 256 * 4))
for frameID = 1, AnimatedWaterPlane.NUM_FRAMES_PER_TEXTURE_ANIMATION do
	local fileName = format("water%d%02d.jpg", 0, frameID - 1)
	local waterTexturePath = path.join("Tests", "Fixtures", "Borftopia", "texture", "워터", fileName)

	local blankImageBytes = C_ImageProcessing.EncodeJPG(blankImage, 256, 256)

	C_FileSystem.MakeDirectoryTree(path.dirname(waterTexturePath))
	C_FileSystem.WriteFile(waterTexturePath, blankImageBytes)
end

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
			assertEquals(#map.meshes, 2 + 1)
			assertEquals(#map.meshes, #groundMeshSections + #waterPlanes)

			assertImageChecksumMatches(map.meshes[1].diffuseTextureImage.rgbaImageBytes, gradientTexture)
			assertEquals(map.meshes[1].diffuseTextureImage.width, 256)
			assertEquals(map.meshes[1].diffuseTextureImage.height, 256)
			assertEquals(map.meshes[1].vertexPositions, groundMeshSections[1].vertexPositions)
			assertEquals(map.meshes[1].vertexColors, groundMeshSections[1].vertexColors)
			assertEquals(map.meshes[1].triangleConnections, groundMeshSections[1].triangleConnections)
			assertEquals(map.meshes[1].diffuseTextureCoords, groundMeshSections[1].diffuseTextureCoords)

			assertImageChecksumMatches(map.meshes[2].diffuseTextureImage.rgbaImageBytes, gridTexture)
			assertEquals(map.meshes[2].diffuseTextureImage.width, 256)
			assertEquals(map.meshes[2].diffuseTextureImage.height, 256)
			assertEquals(map.meshes[2].vertexPositions, groundMeshSections[2].vertexPositions)
			assertEquals(map.meshes[2].vertexColors, groundMeshSections[2].vertexColors)
			assertEquals(map.meshes[2].triangleConnections, groundMeshSections[2].triangleConnections)
			assertEquals(map.meshes[2].diffuseTextureCoords, groundMeshSections[2].diffuseTextureCoords)

			assertEquals(map.meshes[3].diffuseTextureImages[1].rgbaImageBytes, blankImage)
			assertEquals(map.meshes[3].diffuseTextureImages[1].width, 256)
			assertEquals(map.meshes[3].diffuseTextureImages[1].height, 256)
			assertEquals(map.meshes[3].vertexPositions, waterPlanes[1].surfaceGeometry.vertexPositions)
			assertEquals(map.meshes[3].vertexColors, waterPlanes[1].surfaceGeometry.vertexColors)
			assertEquals(map.meshes[3].triangleConnections, waterPlanes[1].surfaceGeometry.triangleConnections)
			assertEquals(map.meshes[3].diffuseTextureCoords, waterPlanes[1].surfaceGeometry.diffuseTextureCoords)

			assertEqualNumbers(map.ambientLight.red, 0.25, 1E-3)
			assertEqualNumbers(map.ambientLight.green, 0.55, 1E-3)
			assertEqualNumbers(map.ambientLight.blue, 0.77, 1E-3)
			assertEqualNumbers(map.ambientLight.intensity, 1, 1E-3)

			assertEqualNumbers(map.directionalLight.red, 13, 1E-3)
			assertEqualNumbers(map.directionalLight.green, 14, 1E-3)
			assertEqualNumbers(map.directionalLight.blue, 15, 1E-3)
			assertEqualNumbers(map.directionalLight.intensity, 1, 1E-3)
			assertEqualNumbers(map.directionalLight.rayDirection.x, 0.49999997019768, 1E-3)
			assertEqualNumbers(map.directionalLight.rayDirection.y, -0.70710676908493, 1E-3)
			assertEqualNumbers(map.directionalLight.rayDirection.z, 0.49999997019768, 1E-3)
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

for frameID = 1, AnimatedWaterPlane.NUM_FRAMES_PER_TEXTURE_ANIMATION do
	local fileName = format("water%d%02d.jpg", 0, frameID - 1)
	local waterTexturePath = path.join("Tests", "Fixtures", "Borftopia", "texture", "워터", fileName)
	C_FileSystem.Delete(waterTexturePath)
end
