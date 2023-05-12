local spec = require "coredor.spec"
local coredor = require "coredor"

describe("list directories", function()
    local utils = require "obs.utils"
    local list_directories = utils.list_directories
    local temp_file_fixture = spec.temp_file_fixture()

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
        local file_path = temp_file_fixture.path

        assert.has_error(function()
            list_directories(file_path)
        end, "path '" .. file_path .. "' must point to directory, not a file")
    end)
end)
