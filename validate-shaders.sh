set -e

SHADERS_DIR=$(pwd)/Core/NativeClient/Shaders

find $SHADERS_DIR -type f -exec bash -c 'echo "Validating shader: {}"; naga {}' \; 