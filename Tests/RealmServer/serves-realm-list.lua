local RealmServer = require("Core.RealmServer")

RealmServer:Start()

local uv = require("uv")

local function onRealmListReceived(client, chunk)
	local expectedFileContents = C_FileSystem.ReadFile("Config/realm-list.json")
	local expectedContentLength = #expectedFileContents
	local contentLength = tonumber(chunk:match("Content%-Length: (%d+)"))
	local contentType = chunk:match("Content%-Type: application/json; charset=utf%-8")
	local status = chunk:match("HTTP/1%.1 200 OK")
	local responseBody = chunk:sub(#chunk - contentLength + 1)

	client:shutdown()
	client:close()

	assert(status == "HTTP/1.1 200 OK", "Should receive response with HTTP status 200 OK")
	assert(
		contentType == "Content-Type: application/json; charset=utf-8",
		"Should receive response with the expected content type"
	)
	assert(contentLength == expectedContentLength, "Should receive the expected content length header")
	assert(responseBody == expectedFileContents, "Should receive the realm list as stored on disk")
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

			-- Daringly, assume it arrives in a single chunk (because it's unlikely to ever exceed the OS' buffer size)
			onRealmListReceived(client, chunk)
		end)
		client:write("GET " .. realmsRoute .. " HTTP/1.1\r\nHost: example.com\r\n\r\n")
	end)
end

createTestClient("/realms/")
createTestClient("/realms")

C_Timer.After(100, function()
	RealmServer:Stop()
end)

uv.run()
