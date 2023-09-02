#include <string>
#include <algorithm>
#include <cctype>

#ifdef _WIN32
#include <windows.h>
#else
#include <iconv.h>
#endif

extern "C" { // Ensuring C linkage

#if defined(_WIN32)
    __declspec(dllexport) // Exporting the symbol
#elif defined(__GNUC__)
    __attribute__((visibility("default")))
#endif

const char* NormalizeFilePath(const char* input);

} // end of extern "C"

std::string NormalizeFilePathCPP(const std::string& input) {
    char output[1024];
#ifdef _WIN32
    // Windows code
    int CP949 = 949;
    // int CP_UTF8 = 65001;
    wchar_t unicodeStr[1024];

    MultiByteToWideChar(CP949, 0, input.c_str(), -1, unicodeStr, 1024);
    WideCharToMultiByte(CP_UTF8, 0, unicodeStr, -1, output, 1024, NULL, NULL);
#else
    // POSIX code
    iconv_t cd = iconv_open("UTF-8", "CP949");
    if (cd == (iconv_t)-1) {
        return "iconv_open failed";
    }

    char *inbuf = strdup(input.c_str());
    char *outbuf = output;
    size_t inbytesleft = input.size();
    size_t outbytesleft = 1024;

    if (iconv(cd, &inbuf, &inbytesleft, &outbuf, &outbytesleft) == (size_t)-1) {
        return "iconv failed";
    }

    iconv_close(cd);
#endif

    std::string normalizedOutput(output);
    std::replace(normalizedOutput.begin(), normalizedOutput.end(), '\\', '/');
    std::transform(normalizedOutput.begin(), normalizedOutput.end(), normalizedOutput.begin(),
        [](unsigned char c) { return std::tolower(c); });

    // Remove leading path separator if present
    if (normalizedOutput[0] == '/') {
        normalizedOutput = normalizedOutput.substr(1);
    }

    // Remove duplicate path separators
    auto newEnd = std::unique(normalizedOutput.begin(), normalizedOutput.end(),
        [](char a, char b) {
            return a == b && a == '/';
        });
    normalizedOutput.erase(newEnd, normalizedOutput.end());

    return normalizedOutput;
}

const char* NormalizeFilePath(const char* input) {
    static std::string output;
    output = NormalizeFilePathCPP(input);
    return output.c_str();
}