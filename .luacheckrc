std = "lua51"
max_line_length = false
exclude_files = {}
ignore = {
	"143", -- accessing undefined feld of global (nonstandard extensions that are part of the runtime)
	"212", -- unused argument 'self'; not a problem and commonly used for colon notation
	"213", -- unused variable (kept for readability, e.g., in loops)
}
globals = {
	-- Runtime APIs
	"C_FileSystem",
	"C_Runtime",
	"C_Timer",
	"C_WebView",
	"after",
	"assertEqualNumbers",
	"assertEquals",
	"assertFalse",
	"assertThrows",
	"assertTrue",
	"before",
	"buffer",
	"describe",
	"dump",
	"format",
	"it",
	"path",
	"printf",
}
