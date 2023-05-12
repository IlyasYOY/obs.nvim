local spec = require "coredor.spec"
local coredor = require "coredor"

describe("list directories", function()
    local utils = require "obs.utils"
    local list_directories = utils.list_folders
    local temp_file_fixture = spec.temp_file_fixture()
    local temp_dir_fixture = spec.temp_dir_fixture()

    it("nil parameter causes error", function()
        assert.has_error(function()
            list_directories()
        end, "path must not be nil")
    end)

    it("not existing directory causes error", function()
        local invalid_directory_path = "invalid directory " .. coredor.uuid()

        assert.has_error(function()
            list_directories(invalid_directory_path)
        end, "path '" .. invalid_directory_path .. "' must exist")
    end)

    it("not directory causes error", function()
        local file_path = temp_file_fixture.path:expand()

        assert.has_error(function()
            list_directories(file_path)
        end, "path '" .. file_path .. "' must point to directory, not a file")
    end)

    it("get current directory", function()
        local temp_dir_path = temp_dir_fixture.path:expand()

        local result = list_directories(temp_dir_path)

        assert.is_not_nil(result)
        assert.list_size(result, 1)
        assert.are.equal(temp_dir_path, result[1])
    end)

    it("get current directory with nested directory", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir = temp_dir_fixture.path / coredor.uuid()
        nested_dir:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 2)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert.are.equal(nested_dir:expand(), result[2])
    end)

    it("get current directory with 2 nested directories", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / coredor.uuid()
        nested_dir1:mkdir()
        local nested_dir2 = temp_dir_fixture.path / coredor.uuid()
        nested_dir2:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 3)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert(
            nested_dir1:expand() == result[2]
                    and nested_dir2:expand() == result[3]
                or nested_dir1:expand() == result[3]
                    and nested_dir2:expand() == result[2]
        )
    end)

    it("get current directory with 2 inner nested directories", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / coredor.uuid()
        nested_dir1:mkdir()
        local nested_dir2 = nested_dir1 / coredor.uuid()
        nested_dir2:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 3)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert(
            nested_dir1:expand() == result[2]
                    and nested_dir2:expand() == result[3]
                or nested_dir1:expand() == result[3]
                    and nested_dir2:expand() == result[2]
        )
    end)

    it("get current directory with nested directory and file", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / coredor.uuid()
        nested_dir1:mkdir()
        local nested_file = temp_dir_fixture.path / coredor.uuid()
        nested_file:touch()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 2)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert.are.equal(nested_dir1:expand(), result[2])
    end)
end)
