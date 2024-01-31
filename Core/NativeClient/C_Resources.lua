local FogParameters = require("Core.FileFormats.FogParameters")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local C_Resources = {
	GRF_FILE_PATH = "data.grf",
	PERSISTENT_RESOURCES = {
		["data/sprite/cursors.act"] = false,
		["data/sprite/cursors.spr"] = false,
		["data/fogparametertable.txt"] = FogParameters,
	},
}

local self = C_Resources

function C_Resources.PreloadPersistentResources()
	local grf = RagnarokGRF()
	grf:Open(self.GRF_FILE_PATH)

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
