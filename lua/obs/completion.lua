local core = require "obs.utils"

local M = {}

local augroup_name = "ObsNvimCompletion"
local completefunc_name = "obs_nvim_completefunc"
local minimum_version = "nvim-0.12"

_G[completefunc_name] = function(findstart, base)
    return require("obs.completion").completefunc(findstart, base)
end

M.completefunc_option = "v:lua." .. completefunc_name
M.complete_source = "F" .. M.completefunc_option

---@class obs.CompletionOpts
---@field public enabled boolean?
---@field public fuzzy boolean? Use fuzzy note matching; defaults to false.

---@class obs.CompletionContext
---@field public start_col number
---@field public base string
---@field public append_closing_brackets boolean
---@field public name_tail string

---@class obs.CompletionReplacement
---@field public bufnr number
---@field public row number one-based row
---@field public start_col number zero-based byte column
---@field public prefix string
---@field public suffix string
---@field public name_tail string

---@type obs.Vault?
M._vault = nil
M._enabled = false
M._fuzzy = false

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

---@return boolean
local function is_supported()
    return vim.fn.has(minimum_version) == 1
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
        and core.path_has_boundary_prefix(file_name, home_path)
end

---@param line string
---@param cursor_col number zero-based byte column
---@return obs.CompletionContext?
function M._find_wiki_link_context(line, cursor_col)
    cursor_col = math.max(0, math.min(cursor_col, #line))
    local prefix = string.sub(line, 1, cursor_col)
    local suffix = string.sub(line, cursor_col + 1)
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

    local boundary_start
    local boundary_token
    for _, token in ipairs { "]]", "|", "#", "[[" } do
        local position = string.find(suffix, token, 1, true)
        if position and (not boundary_start or position < boundary_start) then
            boundary_start = position
            boundary_token = token
        end
    end
    local has_boundary = boundary_start ~= nil and boundary_token ~= "[["

    return {
        start_col = open_end,
        base = base,
        append_closing_brackets = not has_boundary,
        name_tail = has_boundary and string.sub(suffix, 1, boundary_start - 1)
            or "",
    }
end

---@param base string
---@param append_closing_brackets boolean
---@return table[]
local function complete_notes(base, append_closing_brackets)
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
        if name and (M._fuzzy or core.string_has_prefix(name, base, true)) then
            local word = name
            if append_closing_brackets then
                word = word .. "]]"
            end

            items[#items + 1] = {
                word = word,
                abbr = name,
                kind = "f",
                menu = "[obs]",
                equal = M._fuzzy and 1 or nil,
            }
        end
    end

    table.sort(items, function(left, right)
        return left.abbr < right.abbr
    end)

    if M._fuzzy and base ~= "" then
        return vim.fn.matchfuzzy(items, base, { key = "abbr" })
    end

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

    local row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
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

    local words = complete_notes(base, context.append_closing_brackets)
    if context.name_tail ~= "" then
        ---@type obs.CompletionReplacement
        local replacement = {
            bufnr = vim.api.nvim_get_current_buf(),
            row = row,
            start_col = context.start_col,
            prefix = string.sub(line, 1, context.start_col),
            suffix = string.sub(line, cursor_col + 1),
            name_tail = context.name_tail,
        }
        for _, item in ipairs(words) do
            item.user_data = { obs_nvim = replacement }
        end
    end

    return {
        words = words,
        refresh = "always",
    }
end

---@param item table completed item from v:completed_item
---@param reason string completion reason from v:event
function M._on_complete_done(item, reason)
    if
        not M._enabled
        or reason == "cancel"
        or type(item.word) ~= "string"
        or item.word == ""
        or type(item.user_data) ~= "table"
    then
        return
    end

    ---@type obs.CompletionReplacement?
    local replacement = item.user_data.obs_nvim
    if
        type(replacement) ~= "table"
        or replacement.bufnr ~= vim.api.nvim_get_current_buf()
        or type(replacement.prefix) ~= "string"
        or type(replacement.suffix) ~= "string"
        or type(replacement.name_tail) ~= "string"
        or replacement.name_tail == ""
        or replacement.start_col ~= #replacement.prefix
        or not is_note_buffer(M._vault, replacement.bufnr)
        or not vim.bo.modifiable
    then
        return
    end

    local row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
    if
        row ~= replacement.row
        or cursor_col ~= replacement.start_col + #item.word
        or vim.api.nvim_get_current_line() ~= replacement.prefix .. item.word .. replacement.suffix
        or string.sub(replacement.suffix, 1, #replacement.name_tail)
            ~= replacement.name_tail
    then
        return
    end

    -- A kept selection also reports "discard" on Escape or continued typing.
    -- Join the cleanup to its insertion so undo never restores a partial link.
    if not pcall(vim.cmd.undojoin) then
        return
    end
    vim.api.nvim_buf_set_text(
        replacement.bufnr,
        row - 1,
        cursor_col,
        row - 1,
        cursor_col + #replacement.name_tail,
        {}
    )
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
    M._fuzzy = false
    M._vault = nil
    pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

---@param vault obs.Vault
---@param opts obs.CompletionOpts?
function M.setup(vault, opts)
    opts = opts or {}
    M.disable()

    if not is_supported() then
        return
    end

    M._vault = vault
    M._enabled = opts.enabled ~= false
    M._fuzzy = opts.fuzzy == true

    if not M._enabled then
        return
    end

    local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
    vim.api.nvim_create_autocmd("CompleteDone", {
        group = group,
        callback = function()
            M._on_complete_done(vim.v.completed_item, vim.v.event.reason)
        end,
    })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        group = group,
        callback = function(args)
            M.attach(args.buf)
        end,
    })

    M.attach()
end

return M
