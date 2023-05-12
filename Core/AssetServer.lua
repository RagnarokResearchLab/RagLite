local string_filesize = string.filesize
local printf = _G.printf

local AssetServer = {
	DEFAULT_PORT = 9005,
}

local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

function AssetServer:Start(grfFilePath)
	self:CreateWebServer()
	self:StartWebServer()

	local grf = RagnarokGRF()
	grf:Open(grfFilePath)
	self.grfArchive = grf
end

function AssetServer:Stop()
	self.webserver:StopListening()

	self.grfArchive:Close()
end

function AssetServer:CreateWebServer()
	local HttpServer = require("HttpServer")
	local server = HttpServer()

	server:AddRoute("/*", "GET")

	function server.HTTP_REQUEST_FINISHED(...)
		self:INCOMING_FILE_DATA_REQUEST(...)
	end

	self.webserver = server
end

function AssetServer:StartWebServer()
	self.webserver:StartListening(AssetServer.DEFAULT_PORT)
end

function AssetServer:INCOMING_FILE_DATA_REQUEST(webserver, event, payload)
	local requestID = payload.clientID
	print("[AssetServer] INCOMING_FILE_DATA_REQUEST", requestID)

	local requestDetails = self.webserver:GetRequestDetails(requestID)
	if not requestDetails then
		printf("[AssetServer] Warning: Cannot respond to request %s (peer already dropped)", requestID)
		return
	end

	if requestDetails.endpoint == "/*" then
		self:FILE_DATA_REQUESTED(requestID, requestDetails.url)
	end
end

function AssetServer:FILE_DATA_REQUESTED(requestID, requestedFilePath)
	print("[AssetServer] FILE_DATA_REQUESTED", requestID, requestedFilePath)

	local hasFileInGRF = self.grfArchive:IsFileEntry(requestedFilePath)
	if not hasFileInGRF then
		self:SendNotFoundError(requestID)
		return
	end

	self:SendFileData(requestID, requestedFilePath)
end

function AssetServer:SendFileData(requestID, requestedFilePath)
	print("[AssetServer] Serving file data in response to request " .. requestID)

	local responseBody = self.grfArchive:ExtractFileInMemory(requestedFilePath)
	self.webserver:WriteStatus(requestID, "200 OK")
	self.webserver:WriteHeader(requestID, "Content-Type", "application/octet-stream")
	self.webserver:SendResponse(requestID, responseBody)

	printf("[AssetServer] Responding with %s: %s", string_filesize(#responseBody), requestedFilePath)
end

function AssetServer:SendNotFoundError(requestID)
	print("[AssetServer] Sending 404 error in response to request " .. requestID)
	self.webserver:WriteStatus(requestID, "404 Not Found")
	self.webserver:SendResponse(requestID, "")
end

return AssetServer
