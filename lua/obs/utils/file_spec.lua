---@module "luassert"
---@module "plenary.busted"

local spec = require "obs.utils.spec"
local File = require "obs.utils.file"

describe("change file name", function()
    local dir_fixture = spec.temp_dir_fixture()

    ---resolves file in test dit with specified name
    ---@param name string
    ---@return obs.utils.File
    local function resolve_file_with_name(name)
        ---@type Path
        local file_path = dir_fixture.path / name
        return File:new(file_path:expand())
    end

    ---creates fime in test dir with specified name
    ---@param name string
    ---@return obs.utils.File
    local function create_file_with_name(name)
        local file = resolve_file_with_name(name)
        file:as_plenary():touch()
        return file
    end

    it("should rename", function()
        local file = create_file_with_name "test"

        local expected_name = "new name"

        file:change_name(expected_name)

        assert.file(
            file,
            expected_name,
            resolve_file_with_name(expected_name):path()
        )
    end)

    it("should rename nested directory", function()
        local file = create_file_with_name "test.txt"

        local expected_name = "cool/new name"

        file:change_name(expected_name)

        assert.file(
            file,
            "new name",
            resolve_file_with_name(expected_name):path()
        )
    end)

    it("should rename with extension", function()
        local file = create_file_with_name "test.txt"

        local expected_name = "new name.txt"

        file:change_name(expected_name)

        assert.file(
            file,
            "new name",
            resolve_file_with_name(expected_name):path()
        )
    end)
end)
