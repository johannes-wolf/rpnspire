LUA=lua
LUACHECK=luacheck
LUABUNDLER=luabundler

all: test

test: *.lua
	$(LUA) test.lua

bundle: *.lua
	$(LUABUNDLER) bundle app.lua -p "./?.lua" -o bundle.lua

check: bundle
	$(LUACHECK) bundle.lua

tns: bundle
	./build.sh
