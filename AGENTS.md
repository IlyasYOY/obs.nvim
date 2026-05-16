# obs.nvim Agent Guidelines

## Project Shape
- This is a WIP Neovim Lua plugin for Obsidian-like Markdown notes.
- Runtime source lives under `lua/obs/`; specs are colocated as
  `*_spec.lua` files.
- `lua/obs/init.lua` is the plugin entrypoint and registers the
  `:ObsNvim...` user commands.
- Core modules use module tables/classes with `new()` constructors, plus
  LSPLua annotations for public types and function contracts.
- `plenary.nvim` is the main dependency, especially `plenary.path`.

## Build/Test Commands
- `make test` - run all specs with the local headless Neovim runner.
- `make test-verbose` - run all specs with per-test success output.
- Single spec:
  `nvim --headless --noplugin -u tests/minimal_init.lua -c 'lua require("tests.runner").run({ files = { "path/to/test_spec.lua" }, verbose = true })' -c qa`
- `make lint` - run luacheck and stylua checks.
- `make lint_luacheck` - run luacheck only.
- `make lint_stylua` - run stylua in check mode.
- `make format` - format Lua files with stylua.

## Test Environment Notes
- `tests/minimal_init.lua` sets an isolated runtime and XDG home under
  `.test-home`.
- On a fresh checkout, the test bootstrap clones `nvim-lua/plenary.nvim`
  into `.test-deps/plenary.nvim`, so the first test run may need network
  access.
- Keep tests isolated from the user's real vault/home. Use helpers from
  `lua/obs/utils/spec.lua`, especially temp fixtures and custom assertions.
- Prefer injectable providers such as `time_provider`, `date_provider`, and
  `week_provider` instead of relying on wall-clock time in tests.

## Code Style Guidelines
- Formatting is controlled by `stylua.toml`: 4 spaces, 80 columns, Unix line
  endings, `AutoPreferDouble` quotes, and `call_parentheses = "None"`.
- Put `require` calls at the top of files and bind modules to local
  variables.
- Use snake_case for variables/functions and PascalCase for class-like module
  tables or constructors.
- Use LSPLua annotations: `---@class`, `---@field`, `---@param`, and
  `---@return`.
- Prefer early returns and explicit validation. Do not silently ignore
  user-facing failures; use `vim.notify` where the surrounding code does.
- Keep globals limited to those allowed by `.luacheckrc` (`vim`, busted test
  globals, `assert`, and the existing Telescope/debug globals).

## Implementation Patterns
- Prefer `plenary.path` and the local `obs.utils.file` wrapper for filesystem
  behavior in plugin code.
- Keep user interactions routed through Neovim APIs such as `vim.ui.select`,
  `vim.fn.input`, `vim.api.nvim_create_user_command`, and `vim.api.nvim_put`.
- When adding behavior to vault, journal, templater, link, or file utilities,
  add focused specs near the touched module.
- Wiki link completion lives in `lua/obs/completion.lua` and should stay based
  on built-in Neovim completion (`completefunc` plus the `F` source in
  `complete`). Do not replace user `omnifunc`, do not enable `autocomplete`
  automatically, and keep `completion = { enabled = false }` as the opt-out.
- Completion candidates for `[[...]]` must insert bare note names, not bracketed
  links. The replacement start should remain after the nearest `[[` so applying
  a candidate inside `[[foo]]` preserves one pair of brackets.
- Add or update `lua/obs/completion_spec.lua` when changing completion context
  detection, candidate shape, or buffer-local attach behavior.
- Keep changes scoped to the requested behavior; avoid broad refactors unless
  they are needed to make the fix correct.
