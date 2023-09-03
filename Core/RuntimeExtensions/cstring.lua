local ffi = require("ffi")

ffi.cdef([[
  size_t strlen(const char *str);
  int tolower(int c);
]])

local cstring = {}

function cstring.tolower(cstr, len)
	for i = 0, len - 1 do
		cstr[i] = ffi.C.tolower(cstr[i])
	end
end

function cstring.size(cstr)
	return tonumber(ffi.C.strlen(cstr))
end

local BACKSLASH = string.byte("\\")
local FORWARD_SLASH = string.byte("/")

function cstring.normalize(cstr, len)
	local writeIndex = 0
	local skipNext = false

	for readIndex = 0, len - 1 do
		local c = cstr[readIndex]

		if c == BACKSLASH then
			c = FORWARD_SLASH
		end

		if c == FORWARD_SLASH then
			if skipNext then
				-- Skip this character by not incrementing writeIndex.
				skipNext = false
			else
				cstr[writeIndex] = c
				writeIndex = writeIndex + 1
				skipNext = true
			end
		else
			skipNext = false
			cstr[writeIndex] = c
			writeIndex = writeIndex + 1
		end
	end

	-- Handle the special case where the first character is a slash.
	if cstr[0] == FORWARD_SLASH then
		writeIndex = writeIndex - 1
		for i = 0, writeIndex - 1 do
			cstr[i] = cstr[i + 1]
		end
	end

	-- Null-terminate the string.
	cstr[writeIndex] = 0
end

return cstring
