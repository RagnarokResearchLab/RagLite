set -e

GITHUB_ORGANIZATION="evo-lua"
GITHUB_REPOSITORY="evo-runtime"
REQUIRED_RUNTIME_VERSION="v0.0.14"

PLATFORM=$(uname)

echo "Required runtime version: $REQUIRED_RUNTIME_VERSION"

ASSET_FILE_NAME=""
EXECUTABLE_NAME=""
GITHUB_BASE_URL="https://github.com/$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY/releases/download"

echo "Detected platform: $PLATFORM"

case $PLATFORM in
    MINGW64_NT*|CYGWIN_NT*|MSYS_NT*)
        ASSET_FILE_NAME="evo.exe"
		EXECUTABLE_NAME="evo.exe"
        ;;
    Linux)
        ASSET_FILE_NAME="evo-linux-x64"
		EXECUTABLE_NAME="evo"
        ;;
    Darwin)
        ASSET_FILE_NAME="evo-macos-x64"
		EXECUTABLE_NAME="evo"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

DOWNLOAD_LINK="$GITHUB_BASE_URL/$REQUIRED_RUNTIME_VERSION/$ASSET_FILE_NAME"
echo "Fetching GitHub release: $DOWNLOAD_LINK"
curl --location --silent --output "$EXECUTABLE_NAME" "$DOWNLOAD_LINK"
chmod +x $EXECUTABLE_NAME

echo "Downloaded $ASSET_FILE_NAME for platform: $PLATFORM"
echo "Saved here: $(pwd)/$EXECUTABLE_NAME"
