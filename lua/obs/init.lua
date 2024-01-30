local Vault = require "obs.vault"

local obs = {}

---This functions creates module filesds that hold API tables.
---@param opts obs.VaultOpts
function obs.setup(opts)
    obs.vault = Vault:new(opts)
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

vim.api.nvim_create_user_command("ObsNvimDailyNote", function()
    obs.vault:open_daily()
end, {
    desc = "Opens daily note",
})

vim.api.nvim_create_user_command("ObsNvimWeeklyNote", function()
    obs.vault:open_weekly()
end, {
    desc = "Opens weekly note",
})

vim.api.nvim_create_user_command("ObsNvimFindNote", function()
    obs.vault:find_note()
end, {
    desc = "Find note",
})

vim.api.nvim_create_user_command("ObsNvimFindInJournal", function()
    obs.vault:find_journal()
end, {
    desc = "Find note in journal",
})

vim.api.nvim_create_user_command("ObsNvimFindInNotes", function()
    obs.vault:grep_note()
end, {
    desc = "Find in notes",
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
