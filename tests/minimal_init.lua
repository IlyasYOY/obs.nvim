local uv = vim.uv or vim.loop

local function root(path)
    local source = debug.getinfo(1, "S").source:sub(2)
    local repo = vim.fn.fnamemodify(source, ":p:h:h")
    if path == nil or path == "" then
        return repo
    end
    return repo .. "/" .. path
end

local function join(...)
    return table.concat({ ... }, "/")
end

local function ensure_dir(path)
    vim.fn.mkdir(path, "p")
end

local function ensure_plenary()
    local deps = vim.env.OBS_TEST_DEPS or root ".test-deps"
    local plenary = join(deps, "plenary.nvim")
    local legacy_plenary = root ".tests/site/pack/deps/start/plenary.nvim"

    if not uv.fs_stat(plenary) then
        if uv.fs_stat(legacy_plenary) then
            plenary = legacy_plenary
        else
            ensure_dir(deps)
            print "Installing nvim-lua/plenary.nvim"
            local result = vim.fn.system {
                "git",
                "clone",
                "--depth=1",
                "https://github.com/nvim-lua/plenary.nvim.git",
                plenary,
            }
            if vim.v.shell_error ~= 0 then
                error("failed to install plenary.nvim:\n" .. result)
            end
        end
    end

    vim.opt.runtimepath:prepend(plenary)
end

local test_home = vim.env.OBS_TEST_HOME or root ".test-home"

vim.env.XDG_CONFIG_HOME = vim.env.XDG_CONFIG_HOME or join(test_home, "config")
vim.env.XDG_DATA_HOME = vim.env.XDG_DATA_HOME or join(test_home, "data")
vim.env.XDG_CACHE_HOME = vim.env.XDG_CACHE_HOME or join(test_home, "cache")
vim.env.XDG_STATE_HOME = vim.env.XDG_STATE_HOME or join(test_home, "state")

for _, dir in ipairs {
    vim.env.XDG_CONFIG_HOME,
    vim.env.XDG_DATA_HOME,
    vim.env.XDG_CACHE_HOME,
    vim.env.XDG_STATE_HOME,
} do
    ensure_dir(dir)
end

vim.opt.runtimepath:prepend(root())
vim.opt.swapfile = false
package.path = root "?.lua" .. ";" .. root "?/init.lua" .. ";" .. package.path

ensure_plenary()
