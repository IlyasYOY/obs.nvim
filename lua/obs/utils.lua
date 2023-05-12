local File = require "coredor.file"

local M = {}

---lists folders under a given path
---@param path_string string?
---@return Array<string>
function M.list_folders(path_string)
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

    local result = {
        file:path(),
    }

    -- TODO: Replace with plenary scandir.
    -- somehow it didn't workout, tests were failing.
    -- I guess I was misusing the API.
    local files = file.list(path_string, "**/*")

    for _, found_file in ipairs(files) do
        if found_file:as_plenary():is_dir() then
            result[#result + 1] = found_file:path()
        end
    end

    return result
end

return M
