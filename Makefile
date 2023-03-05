all: format lint test

test:
	nvim --headless -u scripts/minimal-for-lazy.lua -c "PlenaryBustedDirectory lua { minimal_init='./scripts/minimal-for-lazy.lua', sequential=true, }"


lint:
	luacheck lua

format:
	stylua lua

