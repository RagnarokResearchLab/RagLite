set -e

export PATH="$PATH:$(pwd)"

evo Tests/smoke-test.lua
evo Tests/unit-test.lua