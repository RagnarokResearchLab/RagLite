set -e

SHADERS_DIR=Core/NativeClient/WebGPU/Shaders

find $SHADERS_DIR -type f -exec bash -c 'echo "Validating shader source: {}"; echo [naga] $(naga {})' \; 
