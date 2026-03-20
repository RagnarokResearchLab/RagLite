# NOTE: This is not a full port of the MSVC build script, but rather a placeholder for local testing.
# NOTE: Eventually, a proper (more portable) solution will be required. But not today... so this is all there is

mkdir -p BuildArtifacts
RUNTIME_LIBS=""
gcc Core/RagLite2.cpp -o BuildArtifacts/RagLite2 $RUNTIME_LIBS -lm -fvisibility=hidden
