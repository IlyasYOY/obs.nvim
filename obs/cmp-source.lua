local core = require "coredor"

local source = {}

function source.new()
    local self = setmetatable({
        obs = require "obs",
    }, { __index = source })
    return self
end

---@return boolean
function source:is_available()
    local vault_home_path = self.obs.vault._home_path:expand()
    local file_dir = vim.fn.expand "%:p"
    local is_in_vault = core.string_has_prefix(file_dir, vault_home_path, true)
    return vim.bo.filetype == "markdown" and is_in_vault
end

---@return string
function source:get_debug_name()
    return "obs"
end

---find notes to perform completion.
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
    local before_cursor = params.context.cursor_before_line
    if not core.string_has_suffix(before_cursor, "[[", true) then
        callback {
            items = {},
            isIncomplete = false,
        }
        return
    end

    local files = self.obs.vault:list_notes()

    local items = core.array_map(files, function(file)
        local completion_ending = self._get_completion_ending(params)
        ---@type lsp.CompletionItem
        local item = {
            label = file:name(),
            kind = 17,
            insertText = file:name() .. completion_ending,
            data = file,
        }
        return item
    end)

    callback {
        items = items,
        isIncomplete = false,
    }
end

---@param params cmp.SourceCompletionApiParams
---@return string
function source._get_completion_ending(params)
    local after_cursor = params.context.cursor_after_line
    if core.string_has_prefix(after_cursor, "]]", true) then
        return ""
    end
    return "]]"
end

---Resolve doc as content of the file.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
    local file = completion_item.data

    completion_item.documentation = {
        kind = "markdown",
        value = file:read(),
    }

    callback(completion_item)
end

return source
