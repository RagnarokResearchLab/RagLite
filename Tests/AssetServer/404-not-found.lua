local uv = require("uv")

local AssetServer = require("Core.AssetServer")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

AssetServer:Start("Tests/Fixtures/test.grf")

local grf = RagnarokGRF()
grf:Open("Tests/Fixtures/test.grf")

local receivedChunks = buffer.new()

local function assertFileContentsWereReceived(client)
	local receivedData = tostring(receivedChunks)
	local expectedContentLength = 0
	local contentLength = tonumber(receivedData:match("Content%-Length: (%d+)"))
	local status = receivedData:match("HTTP/1%.1 404 Not Found")

	assert(status == "HTTP/1.1 404 Not Found", "Should receive response with HTTP status 404 Not Found")
	assert(contentLength == expectedContentLength, "Should receive the expected content length header")
end

local function createTestClient(requestURL)
	local client = uv.new_tcp()
	client:connect("127.0.0.1", AssetServer.DEFAULT_PORT, function()
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
		client:write("GET " .. requestURL .. " HTTP/1.1\r\nHost: example.com\r\n\r\n")
	end)

	return client
end

local client = createTestClient("/does-not-exist.txt")

C_Timer.After(250, function()
	client:shutdown()
	client:close()

	assertFileContentsWereReceived()

	AssetServer:Stop()
	grf:Close()
end)

uv.run()
