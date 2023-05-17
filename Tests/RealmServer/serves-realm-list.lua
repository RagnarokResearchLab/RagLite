local RealmServer = require("Core.RealmServer")

RealmServer:Start()

local uv = require("uv")

local receivedChunks = buffer.new()

local function assertRealmListWasReceived(client)
	local expectedFileContents = C_FileSystem.ReadFile("Config/realm-list.json")
	local expectedContentLength = #expectedFileContents

	local chunks = tostring(receivedChunks)
	local contentLength = tonumber(chunks:match("Content%-Length: (%d+)"))
	local contentType = chunks:match("Content%-Type: application/json; charset=utf%-8")
	local accessControl = chunks:match("Access%-Control%-Allow%-Origin: %*")
	local status = chunks:match("HTTP/1%.1 200 OK")
	local responseBody = chunks:sub(#chunks - contentLength + 1)

	client:shutdown()
	client:close()

	assert(status == "HTTP/1.1 200 OK", "Should receive response with HTTP status 200 OK")
	assert(
		contentType == "Content-Type: application/json; charset=utf-8",
		"Should receive response with the expected content type"
	)
	assert(contentLength == expectedContentLength, "Should receive the expected content length header")
	assert(responseBody == expectedFileContents, "Should receive the realm list as stored on disk")
	assert(accessControl == "Access-Control-Allow-Origin: *", "Should receive a wildcard CORS header")
end

local function createTestClient(realmsRoute)
	local client = uv.new_tcp()
	client:connect("127.0.0.1", 9004, function()
		client:read_start(function(err, chunk)
			if err then
				error(err, 0)
				return
			end

			if not chunk then -- EOF
				return
			end

			receivedChunks:put(chunk)
		end)
		client:write("GET " .. realmsRoute .. " HTTP/1.1\r\nHost: example.com\r\n\r\n")
	end)

	return client
end

local clientA = createTestClient("/realms/")
local clientB = createTestClient("/realms")

C_Timer.After(150, function()
	assertRealmListWasReceived(clientA)
	assertRealmListWasReceived(clientB)
end)

C_Timer.After(300, function()
	RealmServer:Stop()
end)

uv.run()
