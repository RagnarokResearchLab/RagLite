local WebClient = {}

function WebClient:Start()
	print("Creating BJS demo scene in a native WebView window ...")
	C_WebView.CreateWithDevTools()
	local htmlEntryPoint = C_FileSystem.ReadFile("Core/WebClient/index.html")
	C_WebView.SetHTML(htmlEntryPoint)
	C_WebView.SetWindowTitle("WebView Demo Scene")
	C_WebView.ToggleFullscreenMode()
end

return WebClient
