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

-- check it out at: https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
-- this is a bit different version of the gist

local function hex_to_char(x)
    return string.char(tonumber(x, 16))
end

local function char_to_hex(c)
    return string.format("%%%02X", string.byte(c))
end

---performs urlencoding of a given string
---@param url string?
---@return string?
function M.urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w])", char_to_hex)
    return url
end

---performs url decoding of a given string
---@param url string?
---@return string?
function M.urldecode(url)
    if url == nil then
        return
    end
    url = url:gsub("+", " ")
    url = url:gsub("%%(%x%x)", hex_to_char)
    return url
end

return M
