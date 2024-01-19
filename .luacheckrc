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
	"C_ImageProcessing",
	"C_Runtime",
	"C_Timer",
	"C_WebView",
	"after",
	"assertEqualNumbers",
	"assertEquals",
	"assertFailure",
	"assertFalse",
	"assertThrows",
	"assertTrue",
	"before",
	"buffer",
	"class",
	"classname",
	"describe",
	"dump",
	"extend",
	"format",
	"it",
	"instanceof",
	"new",
	"path",
	"printf",
	"typeof",
}
