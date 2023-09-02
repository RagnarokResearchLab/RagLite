local ffi = require("ffi")

-- Define the external function
ffi.cdef[[
    const char* NormalizeFilePath(const char* input);
]]

-- Load the DLL
local pathLib = ffi.load("grfpath")

-- Use the function
local input = "/HELLO/WORLD.TXT"
local result = ffi.string(pathLib.NormalizeFilePath(input))
print(result) -- should print "hello/world.txt"
