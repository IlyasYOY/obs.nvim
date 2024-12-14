local Path = require "plenary.path"
local utils = require "obs.utils"

local M = {}

---@class obs.utils.spec.Path
---@field public path Path path to the directory

---Creates empty file per test
---@return obs.utils.spec.Path
function M.temp_file_fixture()
    local result = {}

    before_each(function()
        local tmp_file_name = "/tmp/lua-" .. utils.uuid()
        result.path = Path:new(tmp_file_name)
        if not result.path:touch() then
            error "cannot create temp file"
        end
    end)

    after_each(function()
        os.execute("rm -f " .. result.path:expand())
    end)

    return result
end

--- Creates empty directory per test
---@return obs.utils.spec.Path
function M.temp_dir_fixture()
    local result = {}

    before_each(function()
        local tmp_file_name = "/tmp/lua-" .. utils.uuid()
        result.path = Path:new(tmp_file_name)
        if not result.path:mkdir() then
            error "cannot create temp file"
        end
    end)

    after_each(function()
        os.execute("rm -rf " .. result.path:expand())
    end)

    return result
end

---@generic T
---@param list T[]
---@param size number
function M.assert_list_size(list, size)
    assert.are.equal(size, #list, "wrong number of etries")
end

---@param file obs.utils.File
---@param name string?
---@param path string?
function M.assert_file(file, name, path)
    assert.are.equal(name, file:name(), "wrong file name")
    assert.are.equal(path, file:path(), "wrong file path")
end

assert.list_size = M.assert_list_size
assert.file = M.assert_file

return M
