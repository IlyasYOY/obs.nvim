local File = require "coredor.file"

local M = {}

function M.list_directories(path_string)
    if path_string == nil then
        error "path must not be nil"
    end

    local file = File:new(path_string)
    local plenary_file = file:as_plenary()

    if not plenary_file:exists() then
        error("path '" .. path_string .. "' must exist")
    end
    if not plenary_file:is_dir() then
        error(
            "path '" .. path_string .. "' must point to directory, not a file"
        )
    end
end

return M
