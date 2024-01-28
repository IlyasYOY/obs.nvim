all: format lint test

test:
	nvim --headless -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua { minimal_init='./scripts/minimal_init.lua', sequential=true, }"


lint:
	luacheck lua

format:
	stylua lua

