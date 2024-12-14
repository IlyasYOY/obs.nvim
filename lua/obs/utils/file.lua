local utils = require "obs.utils"
local Path = require "plenary.path"

---Simple file wrapper
---TODO: Tests.
--
---@class obs.utils.File
---@field private _plenary_path Path
local File = {}
File.__index = File

---gets file name with extension
---@package
---@return string?
function File:get_name_with_extension()
    local path_split = utils.string_split(self:path(), "/")
    local name_with_extension = path_split[#path_split]
    return name_with_extension
end

---gets file name with out extension
---@package
---@return string?
function File:get_name_with_out_extension()
    local name_with_extension = self:get_name_with_extension()
    if name_with_extension == nil then
        return nil
    end

    local name_with_extension_split =
        utils.string_split(name_with_extension, ".")
    name_with_extension_split[#name_with_extension_split] = nil
    local name_with_out_extension =
        utils.string_merge(name_with_extension_split, ".")

    if name_with_out_extension == "" then
        return name_with_extension
    end
    return name_with_out_extension
end

---name of the file with out extension
---@return string?
function File:name()
    return self:get_name_with_out_extension()
end

---returns path to a file
---@return string?
function File:path()
    return self._plenary_path:expand()
end

--- lists files from path matching glob pattern
---@param path string
---@param glob string
---@return obs.utils.File[]
function File.list(path, glob)
    -- NOTE: Speed this up a bit. Maybe I should use `plenary.scandir`.
    local files_as_text = vim.fn.globpath(path, glob)
    local files_pathes = utils.string_split(files_as_text, "\n")
    local results = utils.array_map(files_pathes, function(file_path)
        return File:new(file_path)
    end)
    return results
end

--- creates file wrapper
---@param path string
---@return obs.utils.File
function File:new(path)
    return setmetatable({
        _plenary_path = Path:new(path),
    }, self)
end

---return plenary object
---@return Path
function File:as_plenary()
    return self._plenary_path
end

---Reads file content as string
---@return string?
function File:read()
    return self._plenary_path:read()
end

---Opens file in buffer for editing
function File:edit()
    vim.fn.execute("edit " .. self:path())
end

---renames current file. Different from mv, it does the renaming only of the file name.
--- /path/test -> to "new" -> /path/new.
--- check tests for details.
---@param new_name string name of the file
---@return boolean
function File:change_name(new_name)
    local parent = self._plenary_path:parent()
    local new_file_path = parent / new_name
    self._plenary_path:rename { new_name = new_file_path:expand() }
end

return File
