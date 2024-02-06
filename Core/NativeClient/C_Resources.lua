local CompiledGRF = require("Core.FileFormats.Optimized.CompiledGRF")
local FogParameters = require("Core.FileFormats.FogParameters")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local C_Resources = {
	GRF_FILE_PATH = "data.grf",
	PERSISTENT_RESOURCES = {
		["data/sprite/cursors.act"] = false,
		["data/sprite/cursors.spr"] = false,
		["data/fogparametertable.txt"] = FogParameters,
	},
	ENABLE_CGRF_CACHING = true,
}

local self = C_Resources

function C_Resources.PreloadPersistentResources()
	local grfFilePath = self.GRF_FILE_PATH

	local hasUpdatedCacheEntry = self.ENABLE_CGRF_CACHING and CompiledGRF:IsCacheUpdated(grfFilePath) or false
	local grfName = path.basename(grfFilePath, path.extname(grfFilePath))
	local cgrfFilePath = path.join(CompiledGRF.CGRF_CACHE_DIRECTORY, grfName .. ".cgrf")

	local cgrfFileContents
	if hasUpdatedCacheEntry then
		printf("CGRF_CACHE_HIT: %s (Restoring table of contents)", cgrfFilePath)
		cgrfFileContents = C_FileSystem.ReadFile(cgrfFilePath)
	end

	local grf = RagnarokGRF()
	grf:Open(self.GRF_FILE_PATH, cgrfFileContents)

	local needsCacheWrite = self.ENABLE_CGRF_CACHING and not hasUpdatedCacheEntry
	if needsCacheWrite then
		cgrfFileContents = CompiledGRF:CompileTableOfContents(grf)
		printf("CGRF_CACHE_WRITE: %s (%s)", cgrfFilePath, string.filesize(#cgrfFileContents))
		C_FileSystem.WriteFile(cgrfFilePath, cgrfFileContents)
	end

	printf("Preloading %d persistent resources from %s", table.count(self.PERSISTENT_RESOURCES), self.GRF_FILE_PATH)
	for filePath, decoder in pairs(self.PERSISTENT_RESOURCES) do
		local fileContents = grf:ExtractFileInMemory(filePath)
		self.PERSISTENT_RESOURCES[filePath] = fileContents
		if decoder then
			printf("Decoding persistent resource: %s", filePath)
			self.PERSISTENT_RESOURCES[filePath] = decoder:DecodeFileContents(fileContents)
		end
	end

	self.grf = grf -- No need to close as reopening would be expensive (OS will free the handle)
end

return C_Resources
