local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local console = require("console")
local json = require("json")
local openssl = require("openssl")

local grfPath = arg[1] or "data.grf"
local withTags = (arg[2] == "--tagged") and true or false -- Hacky, clean up later (if needed)
local grf = RagnarokGRF()
grf:Open(grfPath)
grf:Close()

local jsonString = json.prettier(grf:GetFileList())
local jsonFilePath

local timestamp = os.time() -- Might want a different format (later)?
local digest = openssl.digest.new("sha256")
local chunkSizeInBytes = 1024 * 1024 * 1 -- 1MB seems like the fastest option

-- Compute checksum to make sure content changes are reflected in the tag
if withTags then
	local file = io.open(grfPath, "rb")
	if file then
		local fileSize = file:seek("end")
		file:seek("set")
		printf("Computing checksum over %s - this might take a while!", string.filesize(fileSize))
		console.startTimer("sha256sum")
		while true do
			local chunk = file:read(chunkSizeInBytes)
			if not chunk then -- EOF
				break
			end
			digest:update(chunk)
		end
		console.stopTimer("sha256sum")
		file:close()
	else
		error("Failed to open file " .. grfPath)
	end

	local checksum = digest:final()
	local taggedFileName = format("%s-%s-%s.json", path.basename(grfPath, ".grf"), checksum, timestamp)
	jsonFilePath = path.join("Exports", taggedFileName)
else
	jsonFilePath = path.join("Exports", path.basename(grfPath) .. ".json")
end

C_FileSystem.MakeDirectoryTree(path.dirname(jsonFilePath))
printf("Saving GRF file list as %s", jsonFilePath)
C_FileSystem.WriteFile(jsonFilePath, jsonString)
