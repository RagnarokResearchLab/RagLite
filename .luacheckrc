std = "lua51"
max_line_length = false
exclude_files = {}
ignore = {
	"212", -- unused argument 'self'; not a problem and commonly used for colon notation
}
globals = {
	-- Runtime APIs
	"C_FileSystem",
	"C_Runtime",
	"C_Timer",
	"printf",
}
