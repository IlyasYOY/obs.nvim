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
