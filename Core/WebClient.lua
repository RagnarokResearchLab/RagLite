local WebClient = {
	DEFAULT_RPC_PORT = 9009,
}

function WebClient:Start()
	C_WebView.CreateWithDevTools()

	local htmlEntryPoint = "http://localhost:9005/Core/WebClient/index.html"
	C_WebView.NavigateToURL(htmlEntryPoint) -- Loading the HTML directly won't resolve external files (e.g., CSS)

	C_WebView.SetWindowTitle("RagLite WebClient")
	C_WebView.ToggleFullscreenMode()

	-- Hacky, remove once JSON RPC is usable
	self:CreateWebServer()
	self:StartWebServer()
end

function WebClient:CreateWebServer()
	-- JSON RPC currently crashes the Lua runtime (VM Panic), so registering JS callbacks won't work
	-- This workaround allows controlling the native window from within the WebView until that's fixed
	local HttpServer = require("HttpServer")
	local server = HttpServer()

	server:AddRoute("/webview/*", "GET")

	function server.HTTP_REQUEST_FINISHED(...)
		self:INCOMING_RPC_REQUEST(...)
	end

	self.webserver = server
end

function WebClient:StartWebServer()
	self.webserver:StartListening(WebClient.DEFAULT_RPC_PORT)
end

function WebClient:INCOMING_RPC_REQUEST(webserver, event, payload)
	local requestID = payload.clientID
	print("[WebClient] INCOMING_RPC_REQUEST", requestID)

	local requestDetails = self.webserver:GetRequestDetails(requestID)
	if not requestDetails then
		printf("[WebClient] Warning: Cannot respond to request %s (peer already dropped)", requestID)
		return
	end

	self:WEBVIEW_OPERATION_REQUESTED(requestID, requestDetails.url)
end

function WebClient:WEBVIEW_OPERATION_REQUESTED(requestID, requestedFilePath)
	print("[WebClient] WEBVIEW_OPERATION_REQUESTED", requestID, requestedFilePath)

	if requestedFilePath == "/webview/shutdown" then
		print("[WebClient] Received shutdown request - exiting ...")
		os.exit(0)
	elseif requestedFilePath == "/webview/ping" then
		print("[WebClient] Received PING request - responding with PONG")
		self.webserver:WriteHeader(requestID, "Access-Control-Allow-Origin", "*") -- Avoid CORS issues in the WebView
		self.webserver:SendResponse(requestID, "PONG")
	end
end

return WebClient
