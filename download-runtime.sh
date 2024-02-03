set -e

GITHUB_ORGANIZATION="evo-lua"
GITHUB_REPOSITORY="evo-runtime"
REQUIRED_RUNTIME_VERSION="v0.0.18"

PLATFORM=$(uname)
ARCHITECTURE=$(uname -m)

echo "Required runtime version: $REQUIRED_RUNTIME_VERSION"

ASSET_FILE_NAME=""
EXECUTABLE_NAME=""
GITHUB_BASE_URL="https://github.com/$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY/releases/download"

echo "Detected platform: $PLATFORM ($ARCHITECTURE)"

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
        case $ARCHITECTURE in
            arm64)
                ASSET_FILE_NAME="evo-macos-M1"
            ;;
            x86_64)
                ASSET_FILE_NAME="evo-macos-x64"
	        ;;
            *)
                echo "Unsupported architecture: $ARCHITECTURE"
                exit 1
                ;;
        esac
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
