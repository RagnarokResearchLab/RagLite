#include <iostream>
#include <cstdint>
#include <fstream>
#include <vector>
#include <string>

enum class EntryType : uint8_t {
	File = 0,
	Directory = 1
};

struct FileEntry {
	EntryType Type;
	int32_t Offset;
	int32_t SizeCompressed;
	int32_t SizeOriginal;
	std::string FileName;
};

std::vector<FileEntry> ReadEntries(std::istream& stream, int version) {
	std::vector<FileEntry> entries;

	stream.seekg(-9, std::ios_base::end);
	if(!stream) {
		return entries;
	}

	uint32_t entryTableOffset;
	uint16_t entryCount;

	if(version == 0) {
		stream.read(reinterpret_cast<char*>(&entryTableOffset), sizeof(entryTableOffset));
		stream.read(reinterpret_cast<char*>(&entryCount), sizeof(entryCount));
	} else {
		stream.read(reinterpret_cast<char*>(&entryTableOffset), sizeof(entryTableOffset));
		stream.seekg(2, std::ios_base::cur);
		stream.read(reinterpret_cast<char*>(&entryCount), sizeof(entryCount));
		stream.seekg(1, std::ios_base::cur);
	}

	std::cout << "entryTableOffset: " << entryTableOffset << std::endl;
	std::cout << "entryCount: " << entryCount << std::endl;

	stream.seekg(entryTableOffset, std::ios_base::beg);
	for(size_t i = 0; i < entryCount; i++) {
		uint8_t strLen;

		stream.read(reinterpret_cast<char*>(&strLen), sizeof(strLen));

		FileEntry entry;
		entry.Type = static_cast<EntryType>(stream.get());
		stream.read(reinterpret_cast<char*>(&entry.Offset), sizeof(entry.Offset));
		stream.read(reinterpret_cast<char*>(&entry.SizeCompressed), sizeof(entry.SizeCompressed));
		stream.read(reinterpret_cast<char*>(&entry.SizeOriginal), sizeof(entry.SizeOriginal));

		std::string fileName;
		fileName.resize(strLen);
		stream.read(&fileName[0], strLen);
		stream.seekg(1, std::ios::cur); // Skip null terminator
		entry.FileName = fileName;

		entries.push_back(entry);
	}

	return entries;
}

int main() {

	const std::string EXPECTED_PAK_FILE = "data.pak";
	std::ifstream file(EXPECTED_PAK_FILE, std::ios::binary);
	if(!file) {
		std::cerr << "Failed to open file handle for " << EXPECTED_PAK_FILE << std::endl;
		std::cerr << "Reason: I/O error - make sure this file exists and is readable" << std::endl;
		return 1;
	}

	std::cout << "Reading PAK data from " << EXPECTED_PAK_FILE << " ..." << std::endl;

	auto entries = ReadEntries(file, 0);
	for(const auto& entry : entries) {
		std::cout << "Type: " << static_cast<int>(entry.Type) << std::endl;
		std::cout << "Offset: " << entry.Offset << std::endl;
		std::cout << "SizeCompressed: " << entry.SizeCompressed << std::endl;
		std::cout << "SizeOriginal: " << entry.SizeOriginal << std::endl;
		std::cout << "FileName: " << entry.FileName << std::endl;
		std::cout << std::endl;
	}

	std::cout << "Read " << entries.size() << " entries " << std::endl;

	return 0;
}
