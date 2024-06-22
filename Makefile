all: format lint test

.PHONY: test 
test:
	nvim --headless -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua { minimal_init='./scripts/minimal_init.lua', sequential=true, }"

.PHONY: lint_stylua
lint_stylua:
	stylua --color always --check lua

.PHONY: lint_luacheck
lint_luacheck:
	luacheck lua

.PHONY: lint 
lint: lint_luacheck lint_stylua

.PHONY: format 
format:
	stylua lua

