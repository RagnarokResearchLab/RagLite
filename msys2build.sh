# NOTE: This is not a full port of the MSVC build script, but rather a placeholder for local testing.
# NOTE: Eventually, a proper (more portable) solution will be required. But not today... so this is all there is

mkdir -p BuildArtifacts
RUNTIME_LIBS="-l gdi32 -l shlwapi -l user32 -l xinput -l winmm -l imagehlp -l ws2_32"
gcc Core/RagLite2.cpp -o BuildArtifacts/RagLiteMSYS2.exe $RUNTIME_LIBS