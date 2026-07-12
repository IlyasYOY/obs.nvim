.DEFAULT_GOAL := help

STYLUA ?= stylua
LUACHECK ?= luacheck
NVIM ?= nvim
NVIM_VERSION ?=
DEPDIR ?= .test-deps
CURL ?= curl -fL --retry 5 --retry-delay 5 --retry-connrefused --create-dirs
TEST_HOME ?= $(CURDIR)/.test-home
TEST_WORK ?= $(CURDIR)/.test-work
TEST_HELP_DIR := $(TEST_WORK)/help/doc
TEST_ENV := OBS_TEST_HOME=$(TEST_HOME) OBS_TEST_WORK=$(TEST_WORK)/fixtures XDG_CONFIG_HOME=$(TEST_HOME)/config XDG_DATA_HOME=$(TEST_HOME)/data XDG_CACHE_HOME=$(TEST_HOME)/cache XDG_STATE_HOME=$(TEST_HOME)/state NVIM_LOG_FILE=$(TEST_WORK)/nvim.log
LUA_FILES := lua tests
DOC_FILE := doc/obs.txt

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

.PHONY: all help nvim test test-verbose format format-check lint_stylua lint_luacheck lint help-tags help-check check clean

all: help

help:
	@printf '%s\n' \
		'obs.nvim development targets:' \
		'  make test          Run the headless test suite' \
		'  make test-verbose  Run tests with successful cases shown' \
		'  make format        Format Lua sources with StyLua' \
		'  make lint          Run Luacheck and StyLua checks' \
		'  make help-check    Verify the tracked Vim help tags' \
		'  make check         Run the canonical non-mutating checks' \
		'  make clean         Remove local test artifacts'

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
	@mkdir -p $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c "lua require('tests.runner').run()" -c qa

test-verbose: $(TEST_NVIM_DEPS)
	@mkdir -p $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c "lua require('tests.runner').run({ verbose = true })" -c qa

format:
	$(STYLUA) $(LUA_FILES)

format-check:
	$(STYLUA) --color always --check $(LUA_FILES)

lint_stylua: format-check

lint_luacheck:
	$(LUACHECK) $(LUA_FILES)

lint: lint_luacheck lint_stylua

help-tags: $(TEST_NVIM_DEPS)
	@mkdir -p $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --clean -u NONE -i NONE -n -c "helptags doc" -c qa

help-check: $(TEST_NVIM_DEPS)
	@rm -rf $(TEST_HELP_DIR)
	@mkdir -p $(TEST_HELP_DIR)
	@cp $(DOC_FILE) $(TEST_HELP_DIR)/
	@$(TEST_ENV) $(TEST_NVIM) --headless --clean -u NONE -i NONE -n -c "helptags $(TEST_HELP_DIR)" -c qa
	@cmp -s doc/tags $(TEST_HELP_DIR)/tags || { echo 'doc/tags is stale; run make help-tags'; exit 1; }

check: lint test help-check

clean:
	rm -rf $(DEPDIR) $(TEST_HOME) $(TEST_WORK)
