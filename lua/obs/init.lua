local Calendar = require "obs.calendar"
local Completion = require "obs.completion"
local Vault = require "obs.vault"

local obs = {}

local daily_note_count_warning =
    "ObsNvimDailyNote: use either a count or a date, not both."

---@param args vim.api.keyset.create_user_command.command_args
---@return string?
local function daily_note_date_query(args)
    local date_query = args.args or ""
    local has_count = args.range > 0
    local has_prefixed_count = has_count and args.line1 ~= vim.fn.line "."

    if has_prefixed_count and date_query ~= "" then
        vim.notify(daily_note_count_warning, vim.log.levels.WARN)
        return nil
    end

    if date_query == "" then
        if has_count then
            return "in " .. tostring(args.count) .. " days"
        end

        return ""
    end

    if not has_count then
        return date_query
    end

    if date_query:match "^%-%d%d%-%d%d$" then
        return ("%04d%s"):format(args.count, date_query)
    end

    if date_query:match "^days?%s+ago$" then
        return tostring(args.count) .. " " .. date_query
    end

    vim.notify(daily_note_count_warning, vim.log.levels.WARN)
    return nil
end

---@param args vim.api.keyset.create_user_command.command_args
---@return number
local function link_command_count(args)
    if args.range > 0 then
        return args.count
    end

    return 1
end

---This functions creates module filesds that hold API tables.
---@param opts obs.VaultOpts?
function obs.setup(opts)
    opts = opts or {}
    obs.vault = Vault:new(opts)
    Completion.setup(obs.vault, opts.completion)
end

vim.api.nvim_create_user_command("ObsNvimTemplate", function()
    obs.vault:run_if_note(function()
        obs.vault:find_and_insert_template()
    end)
end, {
    desc = "Inserts notes Template",
})

vim.api.nvim_create_user_command("ObsNvimRandomNote", function()
    obs.vault:open_random_note()
end, {
    desc = "Navigate to random note",
})

vim.api.nvim_create_user_command("ObsNvimCopyObsidianLinkToNote", function()
    obs.vault:copy_obsidian_link_to_current_note()
end, {
    desc = "Copies obsidian link to note",
})

vim.api.nvim_create_user_command("ObsNvimCopyWikiLinkToNote", function()
    obs.vault:copy_wiki_link_to_current_note()
end, {
    desc = "Copies wiki link to note",
})

vim.api.nvim_create_user_command("ObsNvimOpenInObsidian", function()
    obs.vault:open_obsidian_link_to_current_note()
end, {
    desc = "Opens note in Obsidian",
})

vim.api.nvim_create_user_command("ObsNvimFollowLink", function()
    obs.vault:run_if_note(function()
        obs.vault:follow_link()
    end)
end, {
    desc = "Navigate to note",
})

vim.api.nvim_create_user_command("ObsNvimNextLink", function(args)
    obs.vault:run_if_note(function()
        obs.vault:next_link(link_command_count(args), args.bang)
    end)
end, {
    bang = true,
    count = true,
    desc = "Navigate to next link",
})

vim.api.nvim_create_user_command("ObsNvimPrevLink", function(args)
    obs.vault:run_if_note(function()
        obs.vault:next_link(-link_command_count(args), args.bang)
    end)
end, {
    bang = true,
    count = true,
    desc = "Navigate to previous link",
})

vim.api.nvim_create_user_command("ObsNvimNewNote", function()
    local input = vim.fn.input {
        prompt = "New note name: ",
        default = "",
    }
    local file = obs.vault:create_note(input)
    if file then
        file:edit()
    else
        vim.notify("Note '" .. input .. "' already exists")
    end
end, {
    desc = "Creates new Note",
})

vim.api.nvim_create_user_command("ObsNvimDailyNote", function(args)
    local date_query = daily_note_date_query(args)
    if date_query == nil then
        return
    end

    if args.bang then
        Calendar.open(obs.vault, date_query)
        return
    end

    obs.vault:open_daily(date_query)
end, {
    bang = true,
    complete = function(arg_lead)
        if not obs.vault then
            return {}
        end

        return obs.vault:complete_daily_dates(arg_lead)
    end,
    count = true,
    desc = "Opens daily note",
    nargs = "*",
})

vim.api.nvim_create_user_command("ObsNvimWeeklyNote", function()
    obs.vault:open_weekly()
end, {
    desc = "Opens weekly note",
})

vim.api.nvim_create_user_command("ObsNvimBacklinks", function()
    obs.vault:run_if_note(function()
        obs.vault:find_current_note_backlinks()
    end)
end, {
    desc = "Find in backlinks of the note",
})

vim.api.nvim_create_user_command("ObsNvimRename", function()
    obs.vault:rename_current_note()
end, {
    desc = "Rename the note",
})

vim.api.nvim_create_user_command("ObsNvimMove", function()
    obs.vault:run_if_note(function()
        obs.vault:find_directory_and_move_current_note()
    end)
end, {
    desc = "Move the note",
})

return obs
