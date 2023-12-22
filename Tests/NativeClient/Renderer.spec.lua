local etrace = require("etrace")
local ffi = require("ffi")
local miniz = require("miniz")

local Plane = require("Core.NativeClient.DebugDraw.Plane")
local Renderer = require("Core.NativeClient.Renderer")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local planeMesh = Plane()

local function assertEqualArrayContents(arrayBuffer, arrayTable)
	for index = 0, #arrayTable - 1, 1 do
		-- Assumes no read-fault will occur (OOB array access) because geometry is stored in tables
		-- Also assumes the cdata arrays will be of the right type (i.e., float/uint32 and not uint8)
		assertEquals(arrayTable[index + 1], arrayBuffer[index])
	end
end

VirtualGPU:Enable()
-- The renderer wasn't designed to be testable, so a few hacks are currently required...
Renderer.wgpuDevice = ffi.new("WGPUDevice")
describe("Renderer", function()
	describe("CreateTextureImage", function()
		before(function()
			etrace.clear() -- Discard submitted textures in between tests
		end)

		it("should upload the image data to the GPU", function()
			local rgbaImageBytes, width, height = string.rep("\255\0\0\255", 256 * 256), 256, 256

			Renderer:CreateTextureImage(rgbaImageBytes, width, height)

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

				Renderer:CreateTextureImage(rgbaImageBytes, IMAGE_WIDTH, IMAGE_HEIGHT)
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

			assertEquals(#events, 8)

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

			assertEquals(#events, 3)

			-- It's technically possible that the wrong buffers are destroyed here, but eh...
			assertEquals(events[1].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[2].name, "GPU_BUFFER_DESTROY")
			assertEquals(events[3].name, "GPU_BUFFER_DESTROY")
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
			assertEquals(#Renderer.meshes, 3)
			Renderer:LoadSceneObjects(scene)
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
		end)
	end)
end)

VirtualGPU:Disable()
