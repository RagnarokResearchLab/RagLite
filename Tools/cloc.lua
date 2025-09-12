local console = require("console")
local uv = require("uv")

local recognizedFileTypes = {
	c = "C",
	cpp = "C++",
	h = "C/C++ Header)",
	hpp = "C++ Header",
	lua = "Lua",
	wgsl = "WGSL",
}

local PERCENT = 100
local ALIGNED_LINE_PATTERN = "%-16s%12s %12s %12s %12s %12s"
local HORIZONTAL_ROW = string.rep("-", 80)

local workDir = uv.cwd()
local ignoreList = {
	["DB"] = true,
}

local directoryTree = {}
if #arg == 0 then
	console.startTimer(format("ReadDirectoryTree: %s", workDir))
	directoryTree = C_FileSystem.ReadDirectoryTree(workDir)
	console.stopTimer(format("ReadDirectoryTree: %s", workDir))
else
	for index, arg in ipairs(arg) do
		local fileSystemPath = path.join(workDir, arg)
		if C_FileSystem.IsDirectory(fileSystemPath) then
			console.startTimer(format("ReadDirectoryTree: %s", fileSystemPath))
			local tree = C_FileSystem.ReadDirectoryTree(fileSystemPath)
			for path, isFile in pairs(tree) do
				directoryTree[path] = true
			end
			console.stopTimer(format("ReadDirectoryTree: %s", fileSystemPath))
			printf("Discovered %d files in %s", table.count(tree), fileSystemPath)
		elseif C_FileSystem.IsFile(fileSystemPath) then
			directoryTree[fileSystemPath] = true
		else
			error(format("Invalid argument %s (not a file or directory)", arg))
		end
	end
end

for ignoredPrefix, _ in pairs(ignoreList) do
	local fileSystemPath = path.join(workDir, ignoredPrefix)
	if C_FileSystem.IsFile(fileSystemPath) then
		printf("Skipping ignored file: %s", fileSystemPath)
		directoryTree[fileSystemPath] = nil
	elseif C_FileSystem.IsDirectory(fileSystemPath) then
		console.startTimer(format("ReadDirectoryTree: %s", fileSystemPath))
		local tree = C_FileSystem.ReadDirectoryTree(fileSystemPath)
		for path, isFile in pairs(tree) do
			directoryTree[path] = nil
		end
		console.stopTimer(format("ReadDirectoryTree: %s", fileSystemPath))
		printf("Skipping %d files in ignored tree %s", table.count(tree), fileSystemPath)
	else
		error(format("Invalid ignoreList entry %s (not a file or directory)", ignoredPrefix))
	end
end

printf("Processing %d files...", table.count(directoryTree))

local defaultStats = {
	fileCount = 0,
	fileSize = 0,
	blankLines = 0,
	commentLines = 0,
	linesOfCode = 0,
}
local aggregatedStats = table.scopy(defaultStats)
local filesStatsByExtension = {}
for extension, humanReadableName in pairs(recognizedFileTypes) do
	filesStatsByExtension[extension] = table.scopy(defaultStats)
end

local LUA_COMMENT_PATTERN = "^[^%-]*%-%-.*$"
local C_COMMENT_PATTERN = "^[^%/]*%/%/.*$"

console.startTimer("ProcessDirectoryTree")
for fileSystemPath, isFile in pairs(directoryTree) do
	local fileExtension = path.extname(fileSystemPath)
	local cacheKey = fileExtension:lower():gsub("%.", "")
	filesStatsByExtension[cacheKey] = filesStatsByExtension[cacheKey] or {}
	if ignoreList[fileSystemPath] then
		printf("Skipping ignored tree: %s", ignoreList)
	else
		if recognizedFileTypes[cacheKey] then
			local bytes = 0
			local lines = 0
			local blankLines = 0
			local commentLines = 0
			local linesOfCode = 0
			local isMultiLineCommentActive = false
			for line in io.lines(fileSystemPath) do
				lines = lines + 1
				bytes = bytes + #line
				local isBlankLine = line:find("^%s*$")
				local singleLineCommentPattern = cacheKey == "lua" and LUA_COMMENT_PATTERN or C_COMMENT_PATTERN
				local isSingleLineComment = line:find(singleLineCommentPattern)

				local isMultiLineCommentStart = cacheKey == "lua" and false or line:find("^%/%*.*$")
				local isMultiLineCommentEnd = cacheKey == "lua" and false or line:find("^[^%*]*%*%/.*$")
				if isMultiLineCommentStart then
					isMultiLineCommentActive = true
				end
				if isMultiLineCommentEnd then
					isMultiLineCommentActive = false
				end

				if
					isSingleLineComment
					or isMultiLineCommentStart
					or isMultiLineCommentEnd
					or isMultiLineCommentActive
				then
					commentLines = commentLines + 1
				elseif isBlankLine then
					blankLines = blankLines + 1
				else
					linesOfCode = linesOfCode + 1
				end
			end

			filesStatsByExtension[cacheKey].fileCount = filesStatsByExtension[cacheKey].fileCount + 1
			filesStatsByExtension[cacheKey].fileSize = filesStatsByExtension[cacheKey].fileSize + bytes
			filesStatsByExtension[cacheKey].blankLines = filesStatsByExtension[cacheKey].blankLines + blankLines
			filesStatsByExtension[cacheKey].commentLines = filesStatsByExtension[cacheKey].commentLines + commentLines
			filesStatsByExtension[cacheKey].linesOfCode = filesStatsByExtension[cacheKey].linesOfCode + linesOfCode

			aggregatedStats.fileCount = aggregatedStats.fileCount + 1
			aggregatedStats.fileSize = aggregatedStats.fileSize + bytes
			aggregatedStats.blankLines = aggregatedStats.blankLines + blankLines
			aggregatedStats.commentLines = aggregatedStats.commentLines + commentLines
			aggregatedStats.linesOfCode = aggregatedStats.linesOfCode + linesOfCode
		end
	end
end
console.stopTimer("ProcessDirectoryTree")

printf(HORIZONTAL_ROW)
local totalFileCount = table.count(directoryTree)
printf("Discovered %d files in directory %s", totalFileCount, workDir)
printf(HORIZONTAL_ROW)
printf(ALIGNED_LINE_PATTERN, "Language", "Files", "Size", "Blank", "Comment", "Code")
printf(HORIZONTAL_ROW)

local orderedFileExtensions = table.keys(recognizedFileTypes)
table.sort(orderedFileExtensions)

local formattedLinesAbsolute = {}
local formattedLinesPercent = {}

for _, fileExtension in ipairs(orderedFileExtensions) do
	local humanReadableFileType = recognizedFileTypes[fileExtension]
	local stats = filesStatsByExtension[fileExtension]
	if stats.fileCount > 0 then
		table.insert(
			formattedLinesAbsolute,
			format(
				ALIGNED_LINE_PATTERN,
				humanReadableFileType,
				stats.fileCount,
				string.filesize(stats.fileSize),
				stats.blankLines,
				stats.commentLines,
				stats.linesOfCode
			)
		)

		local allLines = aggregatedStats.blankLines + aggregatedStats.commentLines + aggregatedStats.linesOfCode
		local filePercent = format("%.1f %%", PERCENT * stats.fileCount / aggregatedStats.fileCount)
		local sizePercent = format("%.1f %%", PERCENT * stats.fileSize / aggregatedStats.fileSize)
		local blankPercent = format("%.1f %%", PERCENT * stats.blankLines / allLines)
		local commentsPercent = format("%.1f %%", PERCENT * stats.commentLines / allLines)
		local codePercent = format("%.1f %%", PERCENT * stats.linesOfCode / allLines)
		table.insert(
			formattedLinesPercent,
			format(
				ALIGNED_LINE_PATTERN,
				humanReadableFileType,
				filePercent,
				sizePercent,
				blankPercent,
				commentsPercent,
				codePercent
			)
		)
	end
end

print(table.concat(formattedLinesAbsolute, "\n"))
printf(HORIZONTAL_ROW)
printf(
	ALIGNED_LINE_PATTERN,
	"Total",
	aggregatedStats.fileCount,
	string.filesize(aggregatedStats.fileSize),
	aggregatedStats.blankLines,
	aggregatedStats.commentLines,
	aggregatedStats.linesOfCode
)
printf(HORIZONTAL_ROW)
print(table.concat(formattedLinesPercent, "\n"))
printf(HORIZONTAL_ROW)

local ONE_HUNDRED_PERCENT = "100.0 %"
local allLines = aggregatedStats.blankLines + aggregatedStats.commentLines + aggregatedStats.linesOfCode

local blankPercent = format("%.1f %%", PERCENT * aggregatedStats.blankLines / allLines)
local commentsPercent = format("%.1f %%", PERCENT * aggregatedStats.commentLines / allLines)
local codePercent = format("%.1f %%", PERCENT * aggregatedStats.linesOfCode / allLines)
printf(
	ALIGNED_LINE_PATTERN,
	"Percentage",
	ONE_HUNDRED_PERCENT,
	ONE_HUNDRED_PERCENT,
	blankPercent,
	commentsPercent,
	codePercent
)
printf(HORIZONTAL_ROW)
