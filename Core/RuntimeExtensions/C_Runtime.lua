function C_Runtime.IsTesting()
	return C_Runtime.isTestRun
end

local RunBasicTests = C_Runtime.RunBasicTests
function C_Runtime.RunBasicTests(...)
	printf("[C_Runtime] BASIC test run detected - some functionality may not be available in this mode")
	C_Runtime.isTestRun = true
	return RunBasicTests(...)
end

local RunDetailedTests = C_Runtime.RunDetailedTests
function C_Runtime.RunDetailedTests(...)
	printf("[C_Runtime] DETAILED test run detected - some functionality may not be available in this mode")
	C_Runtime.isTestRun = true
	return RunDetailedTests(...)
end

local RunMinimalTests = C_Runtime.RunMinimalTests
function C_Runtime.RunSnapshotTests(...)
	printf("[C_Runtime] MINIMAL test run detected - some functionality may not be available in this mode")
	C_Runtime.isTestRun = true
	return RunMinimalTests(...)
end

local RunSnapshotTests = C_Runtime.RunSnapshotTests
function C_Runtime.RunSnapshotTests(...)
	printf("[C_Runtime] SNAPSHOT test run detected - some functionality may not be available in this mode")
	C_Runtime.isTestRun = true
	return RunSnapshotTests(...)
end
