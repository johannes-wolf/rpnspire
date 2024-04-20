lovenspire := "$HOME/Workspace/lovenspire"

test:
	make test
tns:
    make tns

# You need lovenspire for running rpnspire on your
# host OS.
love:
	luabundler bundle app.lua -p "./?.lua" -o bundle.lua
	love {{lovenspire}} ./bundle.lua
