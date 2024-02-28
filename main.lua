-- rm -rf luazip-build && mkdir luazip-build && cp main.lua luazip-build && cp client.lua luazip-build && cp -r Core luazip-build && cp -r DB luazip-build && cd luazip-build && evo build && mv luazip-build raglite && chmod +x raglite && cd - && cp luazip-build/raglite .. && rm -rf luazip-build


-- Placeholder: For the time being, each app has to be started separately
require("client")