local Path = require "plenary.path"

local M = {}

---Merges strings to a text blob
---@param strings string[] array of strings to merge
---@param separator string? a string to be used as separator, default is '\n'
---@return string
local function string_merge(strings, separator)
    if separator == nil then
        separator = "\n"
    end

    local result = ""
    for number, line in ipairs(strings) do
        result = result .. line
        -- add separator in case this is not last iteration
        if number ~= #strings then
            result = result .. separator
        end
    end

    return result
end

M.string_merge = string_merge

---Splits string using separator.
---@param target string to split
---@param separator string
---@return string[]
function M.string_split(target, separator)
    return vim.split(target, separator, { plain = true, trimempty = true })
end

-- Check if str starts with prefix.
---@param str string string to have prefix.
---@param prefix string? prefix itself.
---@param plain boolean? default is false
---@return boolean
local function string_has_prefix(str, prefix, plain)
    if plain == nil then
        plain = false
    end
    if prefix == nil then
        return false
    end

    local index = string.find(str, prefix, 1, plain)

    return index == 1
end

M.string_has_prefix = string_has_prefix

-- Check if str ends with prefix.
---@param str string
---@param suffix string?
---@param plain boolean? default is false
---@return boolean
local function string_has_suffix(str, suffix, plain)
    if suffix == nil then
        return false
    end

    return string_has_prefix(string.reverse(str), string.reverse(suffix), plain)
end

M.string_has_suffix = string_has_suffix

-- Strips tail if present.
-- Works on plain strings.
---@param target string
---@param tail string
---@return string
function M.string_strip_suffix(target, tail)
    if not string_has_suffix(target, tail, true) then
        return target
    end

    return string.sub(target, 1, #target - #tail)
end

-- Strips prefix if present.
-- Works on plain strings.
---@param target string
---@param prefix string
---@return string
function M.string_strip_prefix(target, prefix)
    if not string_has_prefix(target, prefix, true) then
        return target
    end

    return string.sub(target, #prefix + 1, #target)
end

-- Returns text lines selected in V mode.
---@return string[]
local function get_selected_lines()
    local start_position = vim.fn.getpos "'<"
    local end_position = vim.fn.getpos "'>"
    local buffer_number = vim.api.nvim_get_current_buf()

    if end_position[3] == 2147483647 and start_position[3] == 1 then
        return vim.api.nvim_buf_get_lines(
            buffer_number,
            start_position[2] - 1,
            end_position[2],
            false
        )
    else
        return vim.api.nvim_buf_get_text(
            buffer_number,
            start_position[2] - 1,
            start_position[3] - 1,
            end_position[2] - 1,
            end_position[3] - 1,
            {}
        )
    end
end

M.get_selected_lines = get_selected_lines

-- Returns text selected in V mode.
---@return string
function M.get_selected_text()
    local lines = get_selected_lines()
    return string_merge(lines)
end

---Returns path to current file
---@return string
function M.current_working_file()
    return vim.fn.expand "%:."
end

---Returns path to current file
---@return string
function M.current_working_file_dir()
    return vim.fn.expand "%:p:h"
end

-- Saves string to + buffer
---@param string string
function M.save_to_exchange_buffer(string)
    vim.fn.setreg("+", string)
end

---checks if file exists
---@param filename string of the file we read it
---@return boolean if the file exists
local function file_exists(filename)
    ---@type Path
    local path = Path:new(filename)
    return path:exists()
end

M.file_exists = file_exists

---reades lines from file
---@param filename string of the fiel to be read
---@param processor? fun(string):string transforms strings
---@return Array<string> transformed lines
function M.lines_from(filename, processor)
    if not file_exists(filename) then
        return {}
    end

    local lines = {}
    for line in io.lines(filename) do
        if processor ~= nil then
            line = processor(line)
        end
        lines[#lines + 1] = line
    end

    return lines
end

local uuid_template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

---generates uuid as string
---@return string
function M.uuid()
    local uuid_string = string.gsub(uuid_template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
    return uuid_string
end

---maps every element of the array
---@generic T, R
---@param items T[]
---@param mapper fun(T): R
---@return R[]
function M.array_map(items, mapper)
    local results = {}
    for i, item in ipairs(items) do
        results[i] = mapper(item)
    end
    return results
end

---filters items using predicate
---@generic T
---@param items T[]
---@param predicate fun(T): boolean
function M.array_filter(items, predicate)
    local results = {}
    for _, item in ipairs(items) do
        if predicate(item) then
            results[#results + 1] = item
        end
    end
    return results
end

---flatmaps every element of the array
---@generic T, R
---@param items T[]
---@param mapper fun(T): R[]
---@return R[]
function M.array_flat_map(items, mapper)
    local results = {}
    for _, item in ipairs(items) do
        local mapped_items = mapper(item)
        for _, mapped_item in ipairs(mapped_items) do
            results[#results + 1] = mapped_item
        end
    end
    return results
end

---lists folders under a given path
---@param path_string string?
---@return Array<string>
function M.list_folders(path_string)
    if path_string == nil then
        error "path must not be nil"
    end

    local File = require "obs.utils.file"
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
