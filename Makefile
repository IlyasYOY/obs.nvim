all: format lint test

STYLUA ?= stylua
LUACHECK ?= luacheck
NVIM ?= nvim
NVIM_VERSION ?=
DEPDIR ?= .test-deps
CURL ?= curl -fL --retry 5 --retry-delay 5 --retry-connrefused --create-dirs
TEST_HOME ?= $(CURDIR)/.test-home
TEST_DEPS ?= $(abspath $(DEPDIR))
TEST_ENV := OBS_TEST_HOME=$(TEST_HOME) OBS_TEST_DEPS=$(TEST_DEPS) XDG_CONFIG_HOME=$(TEST_HOME)/config XDG_DATA_HOME=$(TEST_HOME)/data XDG_CACHE_HOME=$(TEST_HOME)/cache XDG_STATE_HOME=$(TEST_HOME)/state
LUA_FILES := lua tests

ifeq ($(shell uname -s),Darwin)
  ifeq ($(shell uname -m),arm64)
    NVIM_ARCH ?= macos-arm64
  else
    NVIM_ARCH ?= macos-x86_64
  endif
else
  NVIM_ARCH ?= linux-x86_64
endif

ifneq ($(NVIM_VERSION),)
  NVIM_DIR := $(DEPDIR)/nvim-$(NVIM_VERSION)-$(NVIM_ARCH)
  NVIM_STAMP := $(NVIM_DIR)/.installed
  NVIM_TARBALL := $(NVIM_DIR).tar.gz
  NVIM_URL := https://github.com/neovim/neovim/releases/download/$(NVIM_VERSION)/nvim-$(NVIM_ARCH).tar.gz
  TEST_NVIM := $(NVIM_DIR)/nvim-$(NVIM_ARCH)/bin/nvim
  TEST_NVIM_DEPS := $(NVIM_STAMP)
else
  TEST_NVIM := $(NVIM)
  TEST_NVIM_DEPS :=
endif

.PHONY: nvim test test-verbose format-check lint_stylua lint_luacheck lint format check clean

nvim: $(TEST_NVIM_DEPS)

ifneq ($(NVIM_VERSION),)
$(NVIM_STAMP):
	$(CURL) $(NVIM_URL) -o $(NVIM_TARBALL)
	rm -rf $(NVIM_DIR)
	mkdir -p $(NVIM_DIR)
	tar -xf $(NVIM_TARBALL) -C $(NVIM_DIR)
	rm -f $(NVIM_TARBALL)
	touch $@
endif

test: $(TEST_NVIM_DEPS)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run()" -c qa

test-verbose: $(TEST_NVIM_DEPS)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run({ verbose = true })" -c qa

format-check:
	${STYLUA} --color always --check $(LUA_FILES)

lint_stylua: format-check

lint_luacheck:
	${LUACHECK} $(LUA_FILES)

lint: lint_luacheck lint_stylua

format:
	${STYLUA} $(LUA_FILES)

check: format-check lint_luacheck test

clean:
	rm -rf $(DEPDIR)
