package.path = "?.lua"

local specFiles = {
	"Tests/FileFormats/RagnarokGND.spec.lua",
	"Tests/FileFormats/RagnarokGRF.spec.lua",
	"Tests/FileFormats/RagnarokSPR.spec.lua",
	"Tests/VectorMath/Matrix3D.spec.lua",
	"Tests/VectorMath/Matrix4D.spec.lua",
	"Tests/VectorMath/Vector3D.spec.lua",
	"Tests/AssetServer/AssetServer.spec.lua",
	"Tests/NativeClient/C_Camera.spec.lua",
	"Tests/NativeClient/C_Cursor.spec.lua",
	"Tests/NativeClient/NativeClient.spec.lua",
	"Tests/WorldServer/C_ServerHealth.spec.lua",
	"Tests/WorldServer/WorldServer.spec.lua",
	"Tests/Tools/FileAnalyzer.spec.lua",
	"Tests/Tools/RagnarokTools.spec.lua",
}

local numFailedSections = C_Runtime.RunDetailedTests(specFiles)

os.exit(numFailedSections)
