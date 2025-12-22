# obs.nvim Agent Guidelines

## Build/Test Commands
- `make test` - Run all tests with plenary
- `make test` (single test) - Use `nvim --headless -u scripts/minimal_init.lua -c "PlenaryBustedFile path/to/test_spec.lua"`
- `make lint` - Run luacheck and stylua checks
- `make format` - Format code with stylua
- `make lint_luacheck` - Run luacheck only
- `make lint_stylua` - Check formatting only

## Code Style Guidelines
- **Formatting**: 4 spaces, 80 char column width, double quotes preferred (stylua config)
- **Imports**: Use `require` at top of file, local variables for modules
- **Types**: Use LSPLua annotations with `---@class`, `---@field`, `---@param`, `---@return`
- **Naming**: snake_case for variables/functions, PascalCase for classes/constructors
- **Error handling**: Use early returns, validate inputs, avoid silent failures
- **Globals**: vim, plenary functions, test globals (describe, it, etc.) are allowed
- **Structure**: Follow existing patterns - classes with `new()` constructor, module tables
- **Dependencies**: plenary.nvim is primary dependency, use Path for file operations