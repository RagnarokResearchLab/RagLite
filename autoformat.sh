#!/bin/bash
set -aeo pipefail

STYLUA="stylua"
CLANG_FORMAT="clang-format"

if [[ -x "./stylua" ]]; then
  STYLUA="./stylua"
fi

if [[ -x "./clang-format" ]]; then
  CLANG_FORMAT="./clang-format"
fi

echo "Installed formatters:"
echo

echo $(which $STYLUA)
echo $($STYLUA --version)
echo $(which $CLANG_FORMAT)
echo $($CLANG_FORMAT --version)
echo

echo "Formatting Lua sources ..."

if [ "$1" = "--quick" ]; then
	# Some of the database files are huge, so formatting takes a lot of time and hogs memory
	# Since they're rarely changed, can skip them for local development (but never in CI runs)
    $STYLUA . --syntax luajit --glob '*.lua' --glob '!DB/*'
else
    $STYLUA . --verbose --syntax luajit
fi

echo "Discovering C/C++ sources ..."

RELEVANT_C_FILES_TO_FORMAT=$(find . -type f -name "*.c" -print -o -name "*.h" -print -o -path "*/deps" -prune -o -path "*/ninjabuild-*" -prune)

if [ -n "$RELEVANT_C_FILES_TO_FORMAT" ]; then
	echo "Discovered C sources:"
	echo $RELEVANT_C_FILES_TO_FORMAT

	echo "Formatting C sources ..."
	$CLANG_FORMAT -i --verbose $RELEVANT_C_FILES_TO_FORMAT
else
	echo "NO relevant C sources found"
fi

RELEVANT_CPP_FILES_TO_FORMAT=$(find . -type f -name "*.cpp" -print -o -name "*.hpp" -print -o -path "*/deps" -prune -o -path "*/ninjabuild-*" -prune)
echo "Discovered C++ sources:"
echo $RELEVANT_CPP_FILES_TO_FORMAT

echo "Formatting C++ sources ..."
$CLANG_FORMAT -i --verbose $RELEVANT_CPP_FILES_TO_FORMAT