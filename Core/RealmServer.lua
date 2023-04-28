local printf = _G.printf

local RealmServer = {
	port = 9004,
	realmList = C_FileSystem.ReadFile("Config/realm-list.json"),
}

function RealmServer:Start()
	self:CreateWebServer()
	self:StartWebServer()
end

function RealmServer:Stop()
	self.webserver:StopListening()
end

function RealmServer:CreateWebServer()
	local HttpServer = require("HttpServer")
	local server = HttpServer()

	server:AddRoute("/realms/", "GET")
	server:AddRoute("/realms", "GET")

	function server.HTTP_REQUEST_FINISHED(...)
		self:OnRequest(...)
	end

	self.webserver = server
end

function RealmServer:StartWebServer()
	self.webserver:StartListening(self.port)
end

function RealmServer:OnRequest(webserver, event, payload)
	print("[RealmServer] OnRequest", webserver, event, payload)

	local requestID = payload.clientID
	local requestDetails = self.webserver:GetRequestDetails(requestID)
	if not requestDetails then
		printf("[RealmServer] Warning: Cannot respond to request %s (peer already dropped)", requestID)
		return
	end

	if requestDetails.endpoint == "/realms/" or requestDetails.endpoint == "/realms" then
		self:OnRealmListRequested(requestID)
	end
end

function RealmServer:OnRealmListRequested(requestID)
	print("[RealmServer] OnRealmListRequested", requestID)
	self:SendRealmList(requestID)
end

function RealmServer:SendRealmList(requestID)
	print("[RealmServer] Serving realm list in response to request " .. requestID)

	local responseBody = self.realmList
	self.webserver:WriteStatus(requestID, "200 OK")
	self.webserver:WriteHeader(requestID, "Content-Type", "application/json; charset=utf-8")
	self.webserver:SendResponse(requestID, responseBody)
end

function RealmServer:OnRealmInfoRequested(requestID, realmID)
	print("[RealmServer] OnRealmInfoRequested", requestID, realmID)
end

return RealmServer
