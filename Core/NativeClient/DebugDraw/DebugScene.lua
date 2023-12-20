local DebugScene = {}

function DebugScene:Construct(globallyUniqueSceneID)
	local success, scene = pcall(require, "Core.NativeClient.DebugDraw.Scenes." .. globallyUniqueSceneID)
	if not success then
		return DebugScene("wgpu")
	end
	return scene
end

DebugScene.__index = DebugScene
DebugScene.__call = DebugScene.Construct
setmetatable(DebugScene, DebugScene)

return DebugScene
