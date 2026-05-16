local core = require "obs.utils"

local M = {}

local augroup_name = "ObsNvimCompletion"
local completefunc_name = "obs_nvim_completefunc"

_G[completefunc_name] = function(findstart, base)
    return require("obs.completion").completefunc(findstart, base)
end

M.completefunc_option = "v:lua." .. completefunc_name
M.complete_source = "F" .. M.completefunc_option

---@class obs.CompletionOpts
---@field public enabled boolean?

---@class obs.CompletionContext
---@field public start_col number
---@field public base string

---@type obs.Vault?
M._vault = nil
M._enabled = false

---@param str string
---@param needle string
---@return number?, number?
local function find_last(str, needle)
    local last_start
    local last_end
    local search_start = 1

    while true do
        local start_index, end_index =
            string.find(str, needle, search_start, true)
        if not start_index then
            break
        end

        last_start = start_index
        last_end = end_index
        search_start = start_index + 1
    end

    return last_start, last_end
end

---@param list_string string
---@param value string
---@return boolean
local function comma_list_has_value(list_string, value)
    for _, item in ipairs(vim.split(list_string, ",", { plain = true })) do
        if item == value then
            return true
        end
    end
    return false
end

---@param value string
---@return boolean
local function is_obs_completefunc(value)
    return value == M.completefunc_option
        or string.find(value, "obs.completion", 1, true) ~= nil
        or string.find(value, completefunc_name, 1, true) ~= nil
end

---@param vault obs.Vault?
---@param bufnr number
---@return boolean
local function is_note_buffer(vault, bufnr)
    if not vault or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    local file_name = vim.api.nvim_buf_get_name(bufnr)
    local home_path = vault._home_path:absolute()

    return vim.bo[bufnr].filetype == "markdown"
        and core.string_has_prefix(file_name, home_path, true)
end

---@param line string
---@param cursor_col number zero-based byte column
---@return obs.CompletionContext?
function M._find_wiki_link_context(line, cursor_col)
    cursor_col = math.max(0, math.min(cursor_col, #line))
    local prefix = string.sub(line, 1, cursor_col)
    local _, open_end = find_last(prefix, "[[")
    if not open_end then
        return nil
    end

    local base = string.sub(prefix, open_end + 1)
    if string.find(base, "]]", 1, true) then
        return nil
    end
    if string.find(base, "|", 1, true) or string.find(base, "#", 1, true) then
        return nil
    end

    return {
        start_col = open_end,
        base = base,
    }
end

---@param base string
---@return table[]
local function complete_notes(base)
    if
        not M._enabled
        or not M._vault
        or not M._vault:is_current_buffer_a_note()
    then
        return {}
    end

    local items = {}
    for _, note in ipairs(M._vault:list_notes()) do
        local name = note:name()
        if name and core.string_has_prefix(name, base, true) then
            items[#items + 1] = {
                word = name,
                abbr = name,
                kind = "f",
                menu = "[obs]",
            }
        end
    end

    table.sort(items, function(left, right)
        return left.word < right.word
    end)

    return items
end

---@param findstart number
---@param base string
---@return number|table
function M.completefunc(findstart, base)
    if not M._enabled then
        if findstart == 1 then
            return -3
        end
        return {
            words = {},
            refresh = "always",
        }
    end

    local _, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local context = M._find_wiki_link_context(line, cursor_col)

    if findstart == 1 then
        if
            not context
            or not M._vault
            or not M._vault:is_current_buffer_a_note()
        then
            return -3
        end
        return context.start_col
    end

    if not context then
        return {
            words = {},
            refresh = "always",
        }
    end

    return {
        words = complete_notes(base),
        refresh = "always",
    }
end

---@param bufnr number?
---@return boolean
function M.attach(bufnr)
    if not M._enabled then
        return false
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not is_note_buffer(M._vault, bufnr) then
        return false
    end

    local complete = vim.bo[bufnr].complete
    if not comma_list_has_value(complete, M.complete_source) then
        if complete == "" then
            vim.bo[bufnr].complete = M.complete_source
        else
            vim.bo[bufnr].complete = complete .. "," .. M.complete_source
        end
    end

    local completefunc = vim.bo[bufnr].completefunc
    if completefunc == "" or is_obs_completefunc(completefunc) then
        vim.bo[bufnr].completefunc = M.completefunc_option
    end

    return true
end

function M.disable()
    M._enabled = false
    pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

---@param vault obs.Vault
---@param opts obs.CompletionOpts?
function M.setup(vault, opts)
    opts = opts or {}
    M.disable()

    M._vault = vault
    M._enabled = opts.enabled ~= false

    if not M._enabled then
        return
    end

    local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        group = group,
        callback = function(args)
            M.attach(args.buf)
        end,
    })

    M.attach()
end

return M
