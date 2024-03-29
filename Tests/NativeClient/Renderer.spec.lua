local etrace = require("etrace")
local ffi = require("ffi")

local Plane = require("Core.NativeClient.DebugDraw.Plane")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")
local Renderer = require("Core.NativeClient.Renderer")
local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")
local GroundMeshMaterial = require("Core.NativeClient.WebGPU.Materials.GroundMeshMaterial")
local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")
local Texture = require("Core.NativeClient.WebGPU.Texture")
local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.Materials.WaterSurfaceMaterial")

local planeMesh = Plane()
planeMesh.lightmapTextureCoords = planeMesh.diffuseTextureCoords

local function assertEqualArrayContents(arrayBuffer, arrayTable)
	for index = 0, #arrayTable - 1, 1 do
		-- Assumes no read-fault will occur (OOB array access) because geometry is stored in tables
		-- Also assumes the cdata arrays will be of the right type (i.e., float/uint32 and not uint8)
		assertEquals(arrayTable[index + 1], arrayBuffer[index])
	end
end

VirtualGPU:Enable()

-- Can't upload textures (even to the virtualized GPU) without setting up bind groups first
Renderer:CompileMaterials(Texture.DEFAULT_TEXTURE_FORMAT)

-- The renderer wasn't designed to be testable, so a few hacks are currently required...
Renderer.wgpuDevice = ffi.new("WGPUDevice")
describe("Renderer", function()
	describe("CreateTextureFromImage", function()
		before(function()
			etrace.clear() -- Discard submitted textures in between tests
		end)

		it("should upload the image data to the GPU", function()
			local rgbaImageBytes, width, height = string.rep("\255\0\0\255", 256 * 256), 256, 256

			Renderer:CreateTextureFromImage(rgbaImageBytes, width, height)

			local events = etrace.filter("GPU_TEXTURE_WRITE")
			local payload = events[1].payload

			assertEquals(events[1].name, "GPU_TEXTURE_WRITE")
			assertEquals(payload.dataSize, width * height * 4)
			assertEquals(payload.writeSize.width, width)
			assertEquals(payload.writeSize.height, height)
			assertEquals(payload.writeSize.depthOrArrayLayers, 1)

			assertEquals(#payload.data, #rgbaImageBytes) -- More readable errors in case of failure
			assertEquals(payload.data, rgbaImageBytes)

			assertEquals(tonumber(events[1].payload.dataLayout.offset), 0)
			assertEquals(tonumber(events[1].payload.dataLayout.bytesPerRow), width * 4)
			assertEquals(tonumber(events[1].payload.dataLayout.rowsPerImage), height)
		end)
	end)

	describe("UploadMeshGeometry", function()
		after(function()
			for index, mesh in ipairs(Renderer.meshes) do
				Renderer:DestroyMeshGeometry(mesh)
			end
			etrace.clear() -- Remove all the WebGPU calls
		end)

		it("should add the given mesh to to the list of scene objects to be rendered each frame", function()
			Renderer:UploadMeshGeometry(planeMesh)
			assertEquals(#Renderer.meshes, 1)
			assertEquals(Renderer.meshes[1], planeMesh)
		end)

		it("should upload the mesh's geometry buffers to the GPU", function()
			Renderer:UploadMeshGeometry(planeMesh)
			local events = etrace.filter()

			Renderer:DestroyMeshGeometry(planeMesh)

			assertEquals(#events, 12)

			-- Vertex positions
			local index = 1
			local expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.vertexPositions * ffi.sizeof("float"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.VERTEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("float"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.vertexPositions)

			-- Vertex colors
			index = index + 1
			expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.vertexColors * ffi.sizeof("float"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.VERTEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("float"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.vertexColors)

			-- Index buffer
			index = index + 1
			expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.triangleConnections * ffi.sizeof("uint32_t"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.INDEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("uint32_t"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.triangleConnections)

			-- Diffuse texture coordinates
			index = index + 1
			expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.diffuseTextureCoords * ffi.sizeof("float"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.VERTEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("float"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.diffuseTextureCoords)

			-- Normal vectors
			index = index + 1
			expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.surfaceNormals * ffi.sizeof("float"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.VERTEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("float"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.surfaceNormals)

			-- Lightmap texture coordinates
			index = index + 1
			expectedBufferSize = Buffer.GetAlignedSize(#planeMesh.lightmapTextureCoords * ffi.sizeof("float"))
			assertEquals(events[index].name, "GPU_BUFFER_CREATE")
			assertEquals(events[index].payload.descriptor.usage, Buffer.VERTEX_BUFFER_FLAGS)
			assertEquals(tonumber(events[index].payload.descriptor.size), expectedBufferSize)
			assertEquals(events[index].payload.descriptor.mappedAtCreation ~= 0, false)

			index = index + 1
			assertEquals(events[index].name, "GPU_BUFFER_WRITE")
			assertEquals(events[index].payload.bufferOffset, 0)
			assertEquals(ffi.sizeof(events[index].payload.data), expectedBufferSize * ffi.sizeof("float"))
			assertEquals(events[index].payload.size, expectedBufferSize)
			assertEqualArrayContents(events[index].payload.data, planeMesh.lightmapTextureCoords)
		end)

		it("should throw if the geometry contains an insufficient number of vertex positions", function()
			local mesh = table.copy(planeMesh)
			mesh.vertexPositions = { 0, 1 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_VERTEX_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains an insufficient number of vertex indices", function()
			local mesh = table.copy(planeMesh)
			mesh.triangleConnections = { 0, 1 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_INDEX_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains an insufficient number of vertex colors", function()
			local mesh = table.copy(planeMesh)
			mesh.vertexColors = { 0, 1 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_COLOR_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains an insufficient number of normal components", function()
			local mesh = table.copy(planeMesh)
			mesh.surfaceNormals = { 0, 1 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_NORMAL_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains more vertex positions than colors", function()
			local mesh = table.copy(planeMesh)
			mesh.vertexColors = {}
			local expectedErrorMessage = Renderer.errorStrings.INCOMPLETE_COLOR_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains an insufficient number of diffuse texture coordinates", function()
			local mesh = table.copy(planeMesh)
			mesh.diffuseTextureCoords = { 1, 2, 3 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_UV_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains more vertex positions than diffuse texture coordinates", function()
			local mesh = table.copy(planeMesh)
			mesh.diffuseTextureCoords = {}
			local expectedErrorMessage = Renderer.errorStrings.INCOMPLETE_UV_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains more vertex positions than surface normals", function()
			local mesh = table.copy(planeMesh)
			mesh.surfaceNormals = {}
			local expectedErrorMessage = Renderer.errorStrings.INCOMPLETE_NORMAL_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains an insufficient number of lightmap texture coordinates", function()
			local mesh = table.copy(planeMesh)
			mesh.lightmapTextureCoords = { 1, 2, 3 }
			local expectedErrorMessage = Renderer.errorStrings.INVALID_LIGHTMAP_UV_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should throw if the geometry contains more vertex positions than lightmap texture coordinates", function()
			local mesh = table.copy(planeMesh)
			mesh.lightmapTextureCoords = {}
			local expectedErrorMessage = Renderer.errorStrings.INCOMPLETE_LIGHTMAP_UV_BUFFER
			local function uploadIncompleteMeshGeometry()
				Renderer:UploadMeshGeometry(mesh)
			end
			assertThrows(uploadIncompleteMeshGeometry, expectedErrorMessage)
		end)

		it("should skip geometry that contains no vertex position", function()
			local mesh = table.copy(planeMesh)
			mesh.vertexPositions = {}

			Renderer:UploadMeshGeometry(mesh)
			assertEquals(#Renderer.meshes, 0)

			local events = etrace.filter()
			assertEquals(#events, 0)
		end)

		it("should skip geometry that contains no triangles", function()
			local mesh = table.copy(planeMesh)
			mesh.triangleConnections = {}

			Renderer:UploadMeshGeometry(mesh)
			assertEquals(#Renderer.meshes, 0)

			local events = etrace.filter()
			assertEquals(#events, 0)
		end)
	end)

	describe("DestroyMeshGeometry", function()
		before(function()
			Renderer:UploadMeshGeometry(planeMesh)
			etrace.clear()
		end)

		it("should remove the given mesh from the list of scene events to be rendered each frame", function()
			Renderer:DestroyMeshGeometry(planeMesh)
			assertEquals(#Renderer.meshes, 0)
			assertEquals(Renderer.meshes, {})
		end)

		it("should destroy any uniquely-allocated buffers assigned to the mesh", function()
			Renderer:DestroyMeshGeometry(planeMesh)
			local events = etrace.filter()

			assertEquals(#events, 6)

			-- It's technically possible that the wrong buffers are destroyed here, but eh...
			assertEquals(events[1].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[2].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[3].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[4].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[5].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[6].name, "GPU_BUFFER_DESTROY")
			-- Default texture coordinates shouldn't be destroyed (implicit)
		end)
	end)

	describe("LoadSceneObjects", function()
		after(function()
			Renderer:ResetScene()
		end)

		it("should add all meshes to the scene", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			Renderer:LoadSceneObjects(scene)
			assertEquals(#Renderer.meshes, 4)
			Renderer:LoadSceneObjects(scene)
		end)

		it("should set the ambient light source to the scene's ambient color if one exists", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			scene.ambientLight = { red = 0.1, green = 0.2, blue = 0.3, intensity = 0.4 }

			Renderer.ambientLight.red = 102 / 255
			Renderer.ambientLight.green = 102 / 255
			Renderer.ambientLight.blue = 103 / 255
			Renderer.ambientLight.intensity = 0.5

			Renderer:LoadSceneObjects(scene)

			scene.ambientLight = nil
			assertEquals(Renderer.ambientLight.red, 0.1)
			assertEquals(Renderer.ambientLight.green, 0.2)
			assertEquals(Renderer.ambientLight.blue, 0.3)
			assertEquals(Renderer.ambientLight.intensity, 0.4)
		end)

		it("should set the ambient light source to its default color if the scene doesn't use it", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			assert(scene.ambientLight == nil, tostring(scene.ambientLight))

			Renderer.ambientLight.red = 101 / 255
			Renderer.ambientLight.green = 102 / 255
			Renderer.ambientLight.blue = 103 / 255
			Renderer.ambientLight.intensity = 0.5

			Renderer:LoadSceneObjects(scene)

			scene.ambientLight = nil
			assertEquals(Renderer.ambientLight.red, 1)
			assertEquals(Renderer.ambientLight.green, 1)
			assertEquals(Renderer.ambientLight.blue, 1)
			assertEquals(Renderer.ambientLight.intensity, 1)
		end)

		it("should set the sunlight source to the scene's directional light if one exists", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			scene.directionalLight = {
				red = 0.1,
				green = 0.2,
				blue = 0.3,
				intensity = 0.4,
				rayDirection = {
					x = 1,
					y = 2,
					z = 3,
				},
			}

			Renderer.directionalLight.red = 121 / 255
			Renderer.directionalLight.green = 122 / 255
			Renderer.directionalLight.blue = 123 / 255
			Renderer.directionalLight.intensity = 0.5
			Renderer.directionalLight.rayDirection = {
				x = 4,
				y = 5,
				z = 6,
			}

			Renderer:LoadSceneObjects(scene)

			scene.directionalLight = nil
			assertEquals(Renderer.directionalLight.red, 0.1)
			assertEquals(Renderer.directionalLight.green, 0.2)
			assertEquals(Renderer.directionalLight.blue, 0.3)
			assertEquals(Renderer.directionalLight.intensity, 0.4)
			assertEquals(Renderer.directionalLight.rayDirection.x, 1)
			assertEquals(Renderer.directionalLight.rayDirection.y, 2)
			assertEquals(Renderer.directionalLight.rayDirection.z, 3)
		end)

		it("should set the sunlight source to its default settings if the scene doesn't use it", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			assert(scene.directionalLight == nil, tostring(scene.directionalLight))

			Renderer.directionalLight.red = 100 / 255
			Renderer.directionalLight.green = 101 / 255
			Renderer.directionalLight.blue = 102 / 255
			Renderer.directionalLight.intensity = 0.5
			Renderer.directionalLight.rayDirection = {
				x = 4,
				y = 5,
				z = 6,
			}

			Renderer:LoadSceneObjects(scene)

			scene.directionalLight = nil
			assertEquals(Renderer.directionalLight.red, 1)
			assertEquals(Renderer.directionalLight.green, 1)
			assertEquals(Renderer.directionalLight.blue, 1)
			assertEquals(Renderer.directionalLight.intensity, 1)
			assertEquals(Renderer.directionalLight.rayDirection.x, 1)
			assertEquals(Renderer.directionalLight.rayDirection.y, -1)
			assertEquals(Renderer.directionalLight.rayDirection.z, 1)
		end)

		it("should adjust the fog effect based on the scene's fog parameters if any exist", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			scene.fogParameters = {
				nearLimit = 2,
				farLimit = 300,
				color = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
			}
			Renderer.fogParameters = { color = {} }
			Renderer.fogParameters.color.red = 102 / 255
			Renderer.fogParameters.color.green = 102 / 255
			Renderer.fogParameters.color.blue = 103 / 255
			Renderer.fogParameters.color.alpha = 0.5
			Renderer.fogParameters.nearLimit = 42
			Renderer.fogParameters.farLimit = 420

			Renderer:LoadSceneObjects(scene)

			scene.fogParameters = nil
			assertEquals(Renderer.fogParameters.color.red, 0.1)
			assertEquals(Renderer.fogParameters.color.green, 0.2)
			assertEquals(Renderer.fogParameters.color.blue, 0.3)
			assertEquals(Renderer.fogParameters.color.alpha, 0.4)
			assertEquals(Renderer.fogParameters.nearLimit, 2)
			assertEquals(Renderer.fogParameters.farLimit, 300)
		end)

		it("should disable the fog effect if the scene doesn't use it", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			assert(scene.fogParameters == nil, tostring(scene.fogParameters))

			Renderer.fogParameters = { color = {} }
			Renderer.fogParameters.color.red = 102 / 255
			Renderer.fogParameters.color.green = 102 / 255
			Renderer.fogParameters.color.blue = 103 / 255
			Renderer.fogParameters.color.alpha = 0.5
			Renderer.fogParameters.nearLimit = 42
			Renderer.fogParameters.farLimit = 420

			Renderer:LoadSceneObjects(scene)

			scene.fogParameters = nil
			assertEquals(Renderer.fogParameters, nil)
		end)

		describe("ResetScene", function()
			it("should remove all existing meshes from the scene", function()
				local scene = require("Core.NativeClient.DebugDraw.Scenes.wgpu")
				Renderer:LoadSceneObjects(scene)
				assertEquals(#Renderer.meshes, #scene.meshes)

				etrace.clear()
				Renderer:ResetScene()
				local events = etrace.filter()

				assertEquals(#events, #scene.meshes * Mesh.MAX_BUFFER_COUNT_PER_MESH)
				for index = 1, #scene.meshes * Mesh.MAX_BUFFER_COUNT_PER_MESH, 1 do
					assertEquals(events[index].name, "GPU_BUFFER_DESTROY")
				end
			end)

			it("should reset the scene lighting to its default values", function()
				Renderer.ambientLight = {
					red = 1 / 255,
					green = 2 / 255,
					blue = 3 / 255,
					intensity = 1,
				}
				Renderer.directionalLight = {
					red = 40 / 255,
					green = 41 / 255,
					blue = 42 / 255,
					intensity = 1,
					rayDirection = { x = 10, y = 20, z = 30 },
				}
				Renderer:ResetScene()
				assertEquals(Renderer.ambientLight.red, 1)
				assertEquals(Renderer.ambientLight.green, 1)
				assertEquals(Renderer.ambientLight.blue, 1)
				assertEquals(Renderer.ambientLight.intensity, 1)

				assertEquals(Renderer.directionalLight.red, 1)
				assertEquals(Renderer.directionalLight.green, 1)
				assertEquals(Renderer.directionalLight.blue, 1)
				assertEquals(Renderer.directionalLight.intensity, 1)
				assertEquals(Renderer.directionalLight.rayDirection.x, 1)
				assertEquals(Renderer.directionalLight.rayDirection.y, -1)
				assertEquals(Renderer.directionalLight.rayDirection.z, 1)
			end)

			it("should disable the fog effect", function()
				Renderer.fogParameters = { color = {} }
				Renderer.fogParameters.color.red = 102 / 255
				Renderer.fogParameters.color.green = 102 / 255
				Renderer.fogParameters.color.blue = 103 / 255
				Renderer.fogParameters.color.alpha = 0.5
				Renderer.fogParameters.nearLimit = 42
				Renderer.fogParameters.farLimit = 420

				Renderer:ResetScene()

				assertEquals(Renderer.fogParameters, nil)
			end)
		end)
	end)

	describe("SortMeshesByMaterial", function()
		it("should return a sorted list containing all provided meshes indexed by their material", function()
			local waterPlane = Mesh("SortMeshesByMaterialFakeWaterPlane")
			waterPlane.material = WaterSurfaceMaterial
			local plane = Plane("SortMeshesByMaterialTestPlane")
			plane.material = UnlitMeshMaterial()
			local mesh = Mesh("SortMeshesByMaterialTestMesh")
			mesh.material = UnlitMeshMaterial()
			local ground = Plane("SortMeshesByMaterialFakeGroundMesh")
			ground.material = GroundMeshMaterial()

			local meshes = {
				ground,
				waterPlane,
				plane,
				mesh,
			}
			local meshsSortedByMaterial = Renderer:SortMeshesByMaterial(meshes)

			assertEquals(meshsSortedByMaterial[Renderer.supportedMaterials[UnlitMeshMaterial]], { plane, mesh })
			assertEquals(meshsSortedByMaterial[Renderer.supportedMaterials[GroundMeshMaterial]], { ground })
			assertEquals(meshsSortedByMaterial[Renderer.supportedMaterials[WaterSurfaceMaterial]], { waterPlane })
		end)

		it("should throw if encountering a mesh without an assigned material", function()
			local plane = Plane()
			plane.material = nil

			local expectedErrorMessage =
				format("%s %s (%s)", Renderer.errorStrings.INVALID_MATERIAL, plane.uniqueID, plane.displayName)
			assertThrows(function()
				Renderer:SortMeshesByMaterial({ plane })
			end, expectedErrorMessage)
		end)
	end)

	describe("SaveCapturedScreenshot", function()
		before(function()
			Renderer.SCREENSHOT_OUTPUT_DIRECTORY = "TemporaryScreenshotsDir"
		end)

		after(function()
			local screenshots = C_FileSystem.ReadDirectoryTree(Renderer.SCREENSHOT_OUTPUT_DIRECTORY)
			for screenshotFile, isFile in pairs(screenshots) do
				C_FileSystem.Delete(screenshotFile)
			end
			C_FileSystem.Delete(Renderer.SCREENSHOT_OUTPUT_DIRECTORY)
			Renderer.SCREENSHOT_OUTPUT_DIRECTORY = "Screenshots"
		end)

		it("should create the configured screenshots directory if it doesn't yet exist", function()
			assertFalse(C_FileSystem.Exists(Renderer.SCREENSHOT_OUTPUT_DIRECTORY))
			Renderer:SaveCapturedScreenshot("\255\254\253\0", 1, 1)
			assertTrue(C_FileSystem.Exists(Renderer.SCREENSHOT_OUTPUT_DIRECTORY))
		end)

		it("should save the provided image in the configured screenshots directory", function()
			Renderer:SaveCapturedScreenshot("\000\000\000\000	", 1, 1)
			local screenshots = C_FileSystem.ReadDirectoryTree(Renderer.SCREENSHOT_OUTPUT_DIRECTORY)
			assertEquals(table.count(screenshots), 1)
			for screenshotFile, isFile in pairs(screenshots) do
				local fileContents = C_FileSystem.ReadFile(screenshotFile)
				local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(fileContents)
				assertEquals(width, 1)
				assertEquals(height, 1)
				local expectedImageBytes = "\000\000\000\255" -- JPG doesn't support transparency
				assertEquals(rgbaImageBytes, expectedImageBytes)
			end
		end)
	end)
end)

VirtualGPU:Disable()
