local uv = require("uv")

local string_filesize = string.filesize
local string_lower = string.lower
local printf = _G.printf

local AssetServer = {
	DEFAULT_PORT = 9005,
	-- Only those types that the browser needs for processing the files correctly are relevant here
	relevantContentTypes = {
		[".htm"] = "text/html",
		[".html"] = "text/html",
		[".css"] = "text/css",
		[".js"] = "text/javascript",
		[".wav"] = "audio/wav",
		[".mp3"] = "audio/mpeg",
		[".ogg"] = "audio/ogg",
		[".png"] = "image/png",
		[".jpg"] = "image/jpeg",
		[".bmp"] = "image/bmp",
		[".json"] = "application/json",
	},
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

	self:FILE_DATA_REQUESTED(requestID, requestDetails.url)
end

function AssetServer:FILE_DATA_REQUESTED(requestID, requestedFilePath)
	print("[AssetServer] FILE_DATA_REQUESTED", requestID, requestedFilePath)

	local absoluteFilePath = path.join(uv.cwd(), requestedFilePath)
	local hasFileOnDisk = C_FileSystem.Exists(absoluteFilePath)
	if hasFileOnDisk then
		self:SendLocalFile(requestID, absoluteFilePath)
		return
	end

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

function AssetServer:SendLocalFile(requestID, requestedFilePath)
	print("[AssetServer] Serving local file in response to request " .. requestID)
	local responseBody = C_FileSystem.ReadFile(requestedFilePath)
	local contentType = self:GetContentType(requestedFilePath)

	self.webserver:WriteStatus(requestID, "200 OK")
	self.webserver:WriteHeader(requestID, "Access-Control-Allow-Origin", "*") -- Avoid CORS issues in the WebView
	self.webserver:WriteHeader(requestID, "Content-Type", contentType)
	self.webserver:SendResponse(requestID, responseBody)
end

function AssetServer:GetContentType(requestedFilePath)
	local fileExtension = path.extname(requestedFilePath)
	fileExtension = string_lower(fileExtension)

	return self.relevantContentTypes[fileExtension] or "application/octet-stream"
end

return AssetServer
