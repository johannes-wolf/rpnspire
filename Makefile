LUA=lua
LUACHECK=luacheck

all: test

test: *.lua
	$(LUA) test.lua

check: *.lua
	$(LUACHECK) rpn.lua
