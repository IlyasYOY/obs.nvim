all: format lint test

test:
	nvim --headless -u scripts/minimal-for-lazy.lua -c "PlenaryBustedDirectory tests { minimal_init = './scripts/minimal-for-lazy.lua' }"

lint:
	luacheck lua

format:
	stylua lua

