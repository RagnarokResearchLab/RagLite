# This is also the executable name (for now)
BUILD_DIR=RagLite
mkdir $BUILD_DIR

# Should use the actual main program (later)
cp start-client.lua $BUILD_DIR/main.lua

cd $BUILD_DIR
evo build
rm main.lua
rm $BUILD_DIR.zip
cp ./* ..

cd -

rm -rf $BUILD_DIR