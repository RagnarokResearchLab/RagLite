local WebClient = {}

function WebClient:Start()
	print("Creating BJS demo scene in a native WebView window ...")
	C_WebView.CreateWithDevTools()
	local htmlEntryPoint = "http://localhost:9005/Core/WebClient/index.html"
	C_WebView.NavigateToURL(htmlEntryPoint) -- Loading the HTML directly won't resolve external files (e.g., CSS)
	C_WebView.SetWindowTitle("RagLite WebClient")
	C_WebView.ToggleFullscreenMode()
end

return WebClient
