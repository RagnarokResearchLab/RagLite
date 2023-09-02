#include <iostream>
#include <cassert>
#include "path_normalization.hpp"  // Assuming the function is defined here

void test_convert_euc_kr_to_utf8() {
    std::string result = NormalizeFilePath("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA.txt");
	std::cout << "test_convert_euc_kr_to_utf8: " << result << std::endl;
    assert(result == "유저인터페이스.txt");
}

void test_convert_upper_case_to_lower() {
    std::string result = NormalizeFilePath("TEST.BMP");
	std::cout << "test_convert_upper_case_to_lower: " << result << std::endl;
    assert(result == "test.bmp");
}

void test_remove_leading_path_separators() {
    std::string result = NormalizeFilePath("/hello/world.txt");
	std::cout << "test_remove_leading_path_separators: " << result << std::endl;
    assert(result == "hello/world.txt");
}

void test_replace_windows_path_separators() {
    std::string result = NormalizeFilePath("hello\\world.txt");
	std::cout << "test_replace_windows_path_separators: " << result << std::endl;
    assert(result == "hello/world.txt");
}

void test_remove_duplicate_path_separators() {
    std::string result = NormalizeFilePath("hello\\\\world.txt");
	std::cout << "test_remove_duplicate_path_separators: " << result << std::endl;
    assert(result == "hello/world.txt");
}

int main() {
    test_convert_euc_kr_to_utf8();
    test_convert_upper_case_to_lower();
    test_remove_leading_path_separators();
    test_replace_windows_path_separators();
    test_remove_duplicate_path_separators();
    std::cout << "All tests passed!" << std::endl;
    return 0;
}
