#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

static int run_test(const char* path) {
#if defined(_WIN32)
	STARTUPINFOA si;
	PROCESS_INFORMATION pi;
	DWORD exit_code = 0;

	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);
	ZeroMemory(&pi, sizeof(pi));

	if(!CreateProcessA(NULL, (LPSTR)path, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
		fprintf(stderr, "Failed to start test: %s (error %lu)\n", path, GetLastError());
		return -1;
	}

	WaitForSingleObject(pi.hProcess, INFINITE);
	GetExitCodeProcess(pi.hProcess, &exit_code);

	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);

	return (int)exit_code;
#else
	pid_t pid = fork();
	if(pid == 0) {
		execl(path, path, (char*)NULL);
		perror("execl");
		_exit(127);
	} else if(pid > 0) {
		int status;
		waitpid(pid, &status, 0);
		if(WIFEXITED(status))
			return WEXITSTATUS(status);
		else
			return -1;
	} else {
		perror("fork");
		return -1;
	}
#endif
}

static void alert_failure(const char* test, int code) {
#if defined(_WIN32)
	char buf[256];
	snprintf(buf, sizeof(buf), "Test %s failed (code %d)", test, code);
	MessageBoxA(NULL, buf, "Test Failure", MB_ICONERROR | MB_OK);
#else
	fprintf(stderr, "Test %s failed (code %d)\n", test, code);
#endif
}

int main(int argc, char** argv) {
	if(argc < 2) {
		fprintf(stderr, "Usage: %s test1 [test2 ...]\n", argv[0]);
		return 1;
	}

	int failures = 0;
	for(int i = 1; i < argc; i++) {
		printf("=== Running %s ===\n", argv[i]);
		int code = run_test(argv[i]);
		printf("Test exited with code %d\n", code);
		if(code != 0) {
			failures++;
#if defined(_WIN32)
			if(!getenv("CI")) { // only popup if not in CI
				alert_failure(argv[i], code);
			}
#else
			alert_failure(argv[i], code);
#endif
		}
	}

	printf("\nAll tests finished. Failures: %d\n", failures);
	return failures ? 1 : 0;
}