local etrace = require("etrace")
local ffi = require("ffi")
local miniz = require("miniz")

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

		it("should discard transparent background pixels in the final image", function()
			local IMAGE_WIDTH, IMAGE_HEIGHT = 256, 256
			local transparentColors = {
				"\254\000\254\255",
				"\254\000\255\255",
				"\254\001\254\255",
				"\254\001\255\255",
				"\254\002\254\255",
				"\254\002\255\255",
				"\254\003\254\255",
				"\254\003\255\255",
				"\255\000\254\255",
				"\255\000\255\255",
				"\255\001\254\255",
				"\255\001\255\255",
				"\255\002\254\255",
				"\255\002\255\255",
				"\255\003\254\255",
				"\255\003\255\255",
			}

			local function createImageBytes(pixel)
				return string.rep(pixel, IMAGE_WIDTH * IMAGE_HEIGHT)
			end

			local transparentImages = {}
			for index = 1, #transparentColors, 1 do
				table.insert(transparentImages, createImageBytes(transparentColors[index]))
			end

			-- Only discard alpha to save on unnecessary writes
			local expectedPixelValues = {
				"\254\000\254\000",
				"\254\000\255\000",
				"\254\001\254\000",
				"\254\001\255\000",
				"\254\002\254\000",
				"\254\002\255\000",
				"\254\003\254\000",
				"\254\003\255\000",
				"\255\000\254\000",
				"\255\000\255\000",
				"\255\001\254\000",
				"\255\001\255\000",
				"\255\002\254\000",
				"\255\002\255\000",
				"\255\003\254\000",
				"\255\003\255\000",
			}

			local expectedImages = {}
			for index = 1, #expectedPixelValues, 1 do
				table.insert(expectedImages, createImageBytes(expectedPixelValues[index]))
			end

			local function assertRendererDiscardsTransparentPixelsOnUpload(rgbaImageBytes, expectedResult)
				etrace.clear()

				Renderer:CreateTextureFromImage(rgbaImageBytes, IMAGE_WIDTH, IMAGE_HEIGHT)
				local events = etrace.filter("GPU_TEXTURE_WRITE")
				local payload = events[1].payload

				assertEquals(events[1].name, "GPU_TEXTURE_WRITE")
				assertEquals(payload.dataSize, IMAGE_WIDTH * IMAGE_HEIGHT * 4)
				assertEquals(payload.writeSize.width, IMAGE_WIDTH)
				assertEquals(payload.writeSize.height, IMAGE_HEIGHT)
				assertEquals(payload.writeSize.depthOrArrayLayers, 1)

				assertEquals(#payload.data, #rgbaImageBytes) -- More readable errors in case of failure
				assertEquals(miniz.crc32(payload.data), miniz.crc32(expectedResult))

				assertEquals(tonumber(events[1].payload.dataLayout.offset), 0)
				assertEquals(tonumber(events[1].payload.dataLayout.bytesPerRow), IMAGE_WIDTH * 4)
				assertEquals(tonumber(events[1].payload.dataLayout.rowsPerImage), IMAGE_HEIGHT)
			end

			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[1], expectedImages[1])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[2], expectedImages[2])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[3], expectedImages[3])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[4], expectedImages[4])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[5], expectedImages[5])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[6], expectedImages[6])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[7], expectedImages[7])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[8], expectedImages[8])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[9], expectedImages[9])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[10], expectedImages[10])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[11], expectedImages[11])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[12], expectedImages[12])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[13], expectedImages[13])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[14], expectedImages[14])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[15], expectedImages[15])
			assertRendererDiscardsTransparentPixelsOnUpload(transparentImages[16], expectedImages[16])
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

			assertEquals(#events, 10)

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

			assertEquals(#events, 5)

			-- It's technically possible that the wrong buffers are destroyed here, but eh...
			assertEquals(events[1].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[2].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[3].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[4].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[5].name, "GPU_BUFFER_DESTROY")
			-- Default texture coordinates shouldn't be destroyed (implicit)
		end)
	end)

	describe("LoadSceneObjects", function()
		after(function()
			Renderer:ResetScene()
		end)

		it("should all meshes to the scene", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			Renderer:LoadSceneObjects(scene)
			assertEquals(#Renderer.meshes, 4)
			Renderer:LoadSceneObjects(scene)
		end)

		it("should set the ambient light source to the scene's ambient color if one exists", function()
			local scene = require("Core.NativeClient.DebugDraw.Scenes.cube3d")
			scene.ambientLight = { red = 0.1, green = 0.2, blue = 0.3, intensity = 0.4 }

			Renderer.ambientLight.red = 123 / 255
			Renderer.ambientLight.green = 123 / 255
			Renderer.ambientLight.blue = 123 / 255
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

			Renderer.ambientLight.red = 123 / 255
			Renderer.ambientLight.green = 123 / 255
			Renderer.ambientLight.blue = 123 / 255
			Renderer.ambientLight.intensity = 0.5

			Renderer:LoadSceneObjects(scene)

			scene.ambientLight = nil
			assertEquals(Renderer.ambientLight.red, 1)
			assertEquals(Renderer.ambientLight.green, 1)
			assertEquals(Renderer.ambientLight.blue, 1)
			assertEquals(Renderer.ambientLight.intensity, 1)
		end)

		describe("ResetScene", function()
			it("should remove all existing meshes from the scene", function()
				local scene = require("Core.NativeClient.DebugDraw.Scenes.wgpu")
				Renderer:LoadSceneObjects(scene)
				assertEquals(#Renderer.meshes, 9)

				-- A bit sketchy, but oh well... Better: Track wgpu calls (again)? Maybe later, seems redundant
				_G.assertCallsFunction(function()
					Renderer:ResetScene()
				end, Renderer.DestroyMeshGeometry, 42)
				assertEquals(#Renderer.meshes, 0)
			end)

			it("should reset the scene lighting to its default values", function()
				Renderer.ambientLight = {
					red = 42 / 255,
					green = 42 / 255,
					blue = 42 / 255,
					intensity = 1,
				}
				Renderer:ResetScene()
				assertEquals(Renderer.ambientLight.red, 1)
				assertEquals(Renderer.ambientLight.green, 1)
				assertEquals(Renderer.ambientLight.blue, 1)
				assertEquals(Renderer.ambientLight.intensity, 1)
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
end)

VirtualGPU:Disable()
