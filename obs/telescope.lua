local pickers = require "telescope.pickers"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local builtin = require "telescope.builtin"

local M = {}

-- helper to perform telescope routine
---@param title string name for the widow
---@param items Array<string> items to search through
---@param callback fun(Array)? functions to be applied to the resulting string
---@param entry_maker fun(table): table
---@param opts table? additional options for telescope
function M.find_through_items(title, items, callback, entry_maker, opts)
    opts = opts or {}

    pickers
        .new(opts, {
            prompt_title = title,
            previewer = conf.file_previewer(opts),
            finder = finders.new_table {
                results = items,
                entry_maker = entry_maker,
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                if callback then
                    actions.select_default:replace(function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        callback(selection)
                    end)
                end
                return true
            end,
        })
        :find()
end

---find files using live grep finder from telescope
---@param title string
---@param path string to search files at
---@param type_filter string? file type, check rg docs typelist on the matter
function M.grep_files(title, path, type_filter)
    if type_filter == nil then
        type_filter = "md"
    end

    return builtin.live_grep {
        cwd = path,
        prompt_title = title,
        type_filter = type_filter,
    }
end

---find files using builtin telescope finder.
---@param title string
---@param path string to search files at
---@param hidden boolean? should search for hidden files (default: false)
function M.find_files(title, path, hidden)
    if hidden == nil then
        hidden = false
    end
    return builtin.find_files {
        cwd = path,
        prompt_title = title,
        hidden = hidden,
    }
end

return M
