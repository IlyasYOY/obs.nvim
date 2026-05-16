local uv = vim.uv or vim.loop

---@class obs.utils.Path
---@field private _path string
local Path = {}
Path.__index = Path

Path.path = {
    home = uv.os_homedir() or vim.fn.expand "~",
}

local function is_nil(value)
    return value == nil or value == vim.NIL
end

---@param value any
---@return string
local function to_path_string(value)
    if is_nil(value) then
        return "."
    end

    if type(value) == "table" then
        if getmetatable(value) == Path then
            return value._path
        end

        if type(value.expand) == "function" then
            return value:expand()
        end
    end

    return tostring(value)
end

---@param path string
---@return string
local function trim_trailing_separator(path)
    if #path > 1 then
        path = path:gsub("/+$", "")
    end
    if path == "" then
        return "/"
    end
    return path
end

---@param path string
---@return string
local function normalize(path)
    local expanded = vim.fn.expand(path)
    if expanded == "" then
        expanded = "."
    end
    return trim_trailing_separator(
        vim.fn.resolve(vim.fn.fnamemodify(expanded, ":p"))
    )
end

---@param path string
---@return string
local function parent_path(path)
    return trim_trailing_separator(vim.fn.fnamemodify(path, ":h"))
end

---@param path string
local function ensure_parent(path)
    local parent = parent_path(path)
    if parent ~= "" and parent ~= path then
        vim.fn.mkdir(parent, "p")
    end
end

---@param left string
---@param right string
---@return string
local function join_paths(left, right)
    if right == "" then
        return left
    end
    if right:sub(1, 1) == "/" then
        return right
    end
    if left == "" then
        return right
    end
    return trim_trailing_separator(left) .. "/" .. right:gsub("^/+", "")
end

---@param path string|obs.utils.Path?
---@return obs.utils.Path
function Path:new(path)
    return setmetatable({
        _path = to_path_string(path),
    }, self)
end

---@param child string|obs.utils.Path
---@return obs.utils.Path
function Path:__div(child)
    return Path:new(join_paths(self._path, to_path_string(child)))
end

---@return string
function Path:expand()
    return normalize(self._path)
end

---@return string
function Path:absolute()
    return self:expand()
end

---@return obs.utils.Path
function Path:parent()
    return Path:new(parent_path(self:expand()))
end

---@return boolean
function Path:exists()
    return uv.fs_stat(self:expand()) ~= nil
end

---@return boolean
function Path:is_dir()
    local stat = uv.fs_stat(self:expand())
    return stat ~= nil and stat.type == "directory"
end

---@return boolean
function Path:mkdir()
    if self:is_dir() then
        return true
    end
    return vim.fn.mkdir(self:expand(), "p") == 1
end

---@return boolean
function Path:touch()
    local path = self:expand()
    ensure_parent(path)

    local fd = assert(uv.fs_open(path, "a", 420))
    uv.fs_close(fd)
    return true
end

---@return string?
function Path:read()
    local path = self:expand()
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
        return nil
    end

    local stat = assert(uv.fs_fstat(fd))
    local content = uv.fs_read(fd, stat.size, 0) or ""
    uv.fs_close(fd)
    return content
end

---@param content string
---@param mode string?
---@return boolean
function Path:write(content, mode)
    local path = self:expand()
    ensure_parent(path)

    local flag = mode == "a" and "a" or "w"
    local fd = assert(uv.fs_open(path, flag, 420))
    assert(uv.fs_write(fd, content, -1))
    uv.fs_close(fd)
    return true
end

---@param opts { new_name: string }
---@return boolean
function Path:rename(opts)
    local new_name = assert(opts.new_name, "new_name is required")
    local destination = normalize(new_name)
    ensure_parent(destination)
    assert(uv.fs_rename(self:expand(), destination))
    self._path = destination
    return true
end

---@param opts { destination: string }
---@return boolean
function Path:copy(opts)
    local destination =
        normalize(assert(opts.destination, "destination is required"))
    ensure_parent(destination)
    assert(uv.fs_copyfile(self:expand(), destination))
    return true
end

---@return boolean
function Path:rm()
    return vim.fn.delete(self:expand(), "rf") == 0
end

---@param root string|obs.utils.Path?
---@return string
function Path:make_relative(root)
    local path = self:expand()
    local root_path = Path:new(root or vim.fn.getcwd()):expand()

    if path == root_path then
        return "."
    end

    local root_prefix = trim_trailing_separator(root_path) .. "/"
    if path:sub(1, #root_prefix) == root_prefix then
        return path:sub(#root_prefix + 1)
    end

    return path
end

return Path
