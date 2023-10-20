package.path = "?.lua"

local specFiles = {
	"Tests/FileFormats/BinaryReader.spec.lua",
	"Tests/FileFormats/RagnarokACT.spec.lua",
	"Tests/FileFormats/RagnarokGAT.spec.lua",
	"Tests/FileFormats/RagnarokGND.spec.lua",
	"Tests/FileFormats/RagnarokGR2.spec.lua",
	"Tests/FileFormats/RagnarokGRF.spec.lua",
	"Tests/FileFormats/RagnarokPAL.spec.lua",
	"Tests/FileFormats/RagnarokRGZ.spec.lua",
	"Tests/FileFormats/RagnarokRSW.spec.lua",
	"Tests/FileFormats/RagnarokSPR.spec.lua",
	"Tests/FileFormats/RSW/QuadTreeRange.spec.lua",
	"Tests/VectorMath/Matrix3D.spec.lua",
	"Tests/VectorMath/Matrix4D.spec.lua",
	"Tests/VectorMath/Vector3D.spec.lua",
	"Tests/AssetServer/AssetServer.spec.lua",
	"Tests/NativeClient/WebGPU/Buffer.spec.lua",
	"Tests/NativeClient/C_Camera.spec.lua",
	"Tests/NativeClient/C_Cursor.spec.lua",
	"Tests/NativeClient/NativeClient.spec.lua",
	"Tests/NativeClient/DebugDraw/Box.spec.lua",
	"Tests/NativeClient/DebugDraw/Cone.spec.lua",
	"Tests/NativeClient/DebugDraw/Cylinder.spec.lua",
	"Tests/NativeClient/DebugDraw/Plane.spec.lua",
	"Tests/NativeClient/DebugDraw/Pyramid.spec.lua",
	"Tests/NativeClient/DebugDraw/Sphere.spec.lua",
	"Tests/NativeClient/WebGPU/Texture.spec.lua",
	"Tests/WorldServer/C_ServerHealth.spec.lua",
	"Tests/WorldServer/WorldServer.spec.lua",
	"Tests/Tools/FileAnalyzer.spec.lua",
	"Tests/Tools/RagnarokTools.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
