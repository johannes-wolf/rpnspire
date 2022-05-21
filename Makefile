LUA=lua

all: test

test: *.lua
	$(LUA) test.lua
