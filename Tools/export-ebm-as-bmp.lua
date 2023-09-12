local zlib = require("zlib")

local ebmFilePath = arg[1] or "guild-emblem.ebm"
printf("Exporting EBM: %s", ebmFilePath)

local buffer = C_FileSystem.ReadFile(ebmFilePath)
local bitmap = zlib.inflate()(buffer)

C_FileSystem.WriteFile(ebmFilePath .. ".bmp", bitmap)
