bundle:
	luabundler bundle app.lua -p "./?.lua" -o bundle.lua
build:
	./build.sh
test:
	make test
