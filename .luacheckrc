std = "lua51"
max_line_length = false
exclude_files = {}
ignore = {
	"212", -- unused argument 'self'; not a problem and commonly used for colon notation
	"213", -- unused variable (kept for readability, e.g., in loops)
}
globals = {
	-- Runtime APIs
	"C_FileSystem",
	"C_Runtime",
	"C_Timer",
	"after",
	"assertEqualNumbers",
	"assertEquals",
	"assertThrows",
	"before",
	"describe",
	"it",
	"printf",
}
