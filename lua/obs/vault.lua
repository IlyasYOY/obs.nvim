local Link = require "obs.link"
local Templater = require "obs.templater"
local File = require "obs.utils.file"
local Journal = require "obs.journal"
local Path = require "obs.utils.path"

local core = require "obs.utils"
local utils = require "obs.utils"

-- table with vault options
---@class obs.VaultOpts
---@field public vault_home string?
---@field public vault_name string?
---@field public templater obs.TemplaterOpts?
---@field public journal obs.JournalOpts?
---@field public completion obs.CompletionOpts?
---@field public time_provider fun():number
local VaultOpts = {}

---expands path to full
---@param path string?
---@return string?
local function expand_path(path)
    if not path then
        return nil
    end
    return Path:new(path):expand()
end

-- simple constructor for options
---@param opts obs.VaultOpts?
function VaultOpts:new(opts)
    opts = opts or {}
    self.__index = self
    local vault_opts = setmetatable({}, self)

    vault_opts.time_provider = opts.time_provider or os.time

    vault_opts.vault_home = expand_path(
        opts.vault_home or (Path:new(Path.path.home) / "vimwiki"):expand()
    )
    vault_opts.vault_name = opts.vault_name or "vimwiki"

    vault_opts.templates_home = (
        Path:new(vault_opts.vault_home)
        / "meta"
        / "templates"
    ):expand()

    vault_opts.journal_home = (Path:new(vault_opts.vault_home) / "diary"):expand()

    local templater_opts = opts.templater or {}
    vault_opts.templater = vim.tbl_extend(
        "force",
        { home = vault_opts.templates_home, include_default_providers = true },
        templater_opts
    )
    vault_opts.templater.home = expand_path(vault_opts.templater.home)

    local journal_opts = opts.journal or {}
    vault_opts.journal = vim.tbl_extend("force", {
        home = vault_opts.journal_home,
        time_provider = vault_opts.time_provider,
    }, journal_opts)
    vault_opts.journal.home = expand_path(vault_opts.journal.home)

    return vault_opts
end

---@class obs.Vault
---@field protected _name string
---@field protected _home_path obs.utils.Path
---@field protected _templater obs.Templater
---@field protected _journal obs.Journal
---@field protected _time_provider fun(): number
local Vault = {}

---creates Vault instance
---@param opts obs.VaultOpts? table options to create a vault
---@return obs.Vault
function Vault:new(opts)
    opts = opts or {}

    self.__index = self
    local vault = setmetatable({}, self)

    opts = VaultOpts:new(opts)

    vault._name = opts.vault_name
    ---@type obs.utils.Path
    vault._home_path = Path:new(vim.fn.resolve(opts.vault_home))
    ---@type obs.Templater
    local templater = Templater:new(opts.templater)

    vault._templater = templater
    vault._journal = Journal:new(templater, opts.journal)
    vault._time_provider = opts.time_provider

    return vault
end

---create notes with defaults to name structure applied
---@param name string?
---@return obs.utils.File?
function Vault:create_note(name)
    local time = self._time_provider()
    if not name or name == "" then
        name = time
    end

    local name_prefix = os.date("%Y-%m-%d-", time)
    local fullname = name_prefix .. name
    if self:get_note(fullname) then
        return nil
    end

    ---@type obs.utils.Path
    local new_path = self._home_path / (fullname .. ".md")
    new_path:touch()
    return File:new(new_path:expand())
end

function Vault:find_and_insert_template()
    self._templater:search_and_insert_template()
end

function Vault:find_directory_and_move_current_note()
    local folders = utils.list_folders(self._home_path:expand())
    local current_note_filename = vim.fn.expand "%:t"
    local current_note_fullpath = vim.fn.expand "%"
    local current_buf = vim.api.nvim_get_current_buf()

    vim.ui.select(folders, {
        prompt = "Move note to folder",
        format_item = function(folder_path)
            local file = File:new(folder_path)
            return file:make_relative()
        end,
    }, function(choice)
        if choice then
            local destination = Path:new(choice) / current_note_filename
            local from_file = File:new(current_note_fullpath)
            from_file:copy(destination:expand())
            vim.cmd(current_buf .. "bdelete")
            File:new(destination:expand()):edit()
            from_file:rm()
        end
    end)
end

function Vault:find_current_note_backlinks()
    local current_note = File:new(core.current_working_file())
    self:find_backlinks(current_note:name())
end

---renames the note
---@param name string
---@param new_name string
---@return obs.utils.File?
function Vault:rename(name, new_name)
    local note = self:get_note(name)
    if note == nil then
        vim.notify("note '" .. name .. "' was not found")
        return
    end

    local destination = Path:new(note:path()):parent() / (new_name .. ".md")
    local existing_note = self:get_note(new_name)
    if
        (existing_note ~= nil and existing_note:path() ~= note:path())
        or (destination:exists() and destination:expand() ~= note:path())
    then
        vim.notify("note '" .. new_name .. "' already exists")
        return
    end

    note:change_name(new_name .. ".md")
    self:_update_links_in_notes(name, new_name)

    return self:get_note(new_name)
end

---Returns a link to a current note
---@return string?
function Vault:get_obsidian_link_to_current_note()
    return self:run_if_note(function()
        local current_note = File:new(core.current_working_file())
        local file_name = current_note:make_relative(self._home_path:expand())

        return "obsidian://open?vault="
            .. utils.urlencode(self._name)
            .. "&file="
            .. utils.urlencode(file_name)
    end)
end

---Returns a wiki link to a current note
---@return string?
function Vault:get_wiki_link_to_current_note()
    return self:run_if_note(function()
        local current_note = File:new(core.current_working_file())
        return "[[" .. current_note:name() .. "]]"
    end)
end

---Copies a link to a current note
---@return string
function Vault:copy_obsidian_link_to_current_note()
    local link = self:get_obsidian_link_to_current_note()
    if link then
        vim.notify("link was saved to clipboard: " .. link)
        core.save_to_exchange_buffer(link)
    end
end

---Copies a wiki link to a current note
function Vault:copy_wiki_link_to_current_note()
    local link = self:get_wiki_link_to_current_note()
    if link then
        vim.notify("link was saved to clipboard: " .. link)
        core.save_to_exchange_buffer(link)
    end
end

---Opens current note in Obsidian
function Vault:open_obsidian_link_to_current_note()
    local link = self:get_obsidian_link_to_current_note()
    if link then
        vim.notify("opening a link: " .. link)
        vim.ui.open(link)
    end
end

---Renames current working note (if it's note)
function Vault:rename_current_note()
    self:run_if_note(function()
        local old_name = vim.fn.expand "%:t:r"
        local result = self:rename(
            old_name,
            vim.fn.input {
                prompt = "New name: ",
                default = old_name,
            }
        )
        if result then
            result:edit()
        end
    end)
end

local function escape_magic(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

---opens random note from the vault.
function Vault:open_random_note()
    local notes = self:list_notes()
    if #notes == 0 then
        vim.notify "No notes found"
        return
    end

    local random_note_index = math.random(#notes)
    local random_note = notes[random_note_index]
    random_note:edit()
end

---this function is meant to be used from rename API. It goes throgh links in vault and upates them.
---@param old_note_name string
---@param new_note_name string
function Vault:_update_links_in_notes(old_note_name, new_note_name)
    local links_counter = 0
    local files_counter = 0
    old_note_name = escape_magic(old_note_name)
    for _, note in ipairs(self:list_notes()) do
        local note_text = note:read()
        local updated_count
        local full_updated_counter = 0

        note_text, updated_count = string.gsub(
            note_text,
            "%[%[" .. old_note_name .. "%]%]",
            function()
                return "[[" .. new_note_name .. "]]"
            end
        )
        full_updated_counter = full_updated_counter + updated_count

        note_text, updated_count = string.gsub(
            note_text,
            "%[%[" .. old_note_name .. "%|",
            function()
                return "[[" .. new_note_name .. "|"
            end
        )
        full_updated_counter = full_updated_counter + updated_count

        note_text, updated_count = string.gsub(
            note_text,
            "%[%[" .. old_note_name .. "#",
            function()
                return "[[" .. new_note_name .. "#"
            end
        )
        full_updated_counter = full_updated_counter + updated_count

        if full_updated_counter ~= 0 then
            files_counter = files_counter + 1
            links_counter = links_counter + full_updated_counter
        end

        note:write(note_text, "w")
    end

    vim.notify(
        string.format(
            "updated %d links and %d files",
            links_counter,
            files_counter
        )
    )
end

function Vault:find_backlinks(name)
    local notes = self:list_backlinks(name)
    if #notes == 0 then
        vim.notify "No backlinks found"
        return
    end

    vim.ui.select(notes, {
        prompt = "Backlinks",
        format_item = function(note)
            return note:name()
        end,
    }, function(choice)
        if choice then
            choice:edit()
        end
    end)
end

---follows a link under the cursor
function Vault:follow_link()
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local link = Link.find_link_at(line, col + 1)
    if link ~= nil then
        local name = link.name
        local note = self:get_note(name)
        if note ~= nil then
            note:edit()
            return
        end
    end
    vim.notify "No link was found under the cursor"
end

---@class obs.LinkLocation
---@field public line number one-based line number
---@field public col number zero-based cursor landing column
---@field public start_col number zero-based inclusive start column
---@field public end_col number zero-based inclusive end column
---@field public type "wiki"|"markdown"|"url"

---@class obs.LastLinkLocation : obs.LinkLocation
---@field public bufnr number

---@param include_markdown boolean
---@return obs.LinkLocation[]
local function current_buffer_link_locations(include_markdown)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    ---@type obs.LinkLocation[]
    local locations = {}

    for line_number, line in ipairs(lines) do
        for _, span in ipairs(Link.find_links_in_line(line, include_markdown)) do
            table.insert(locations, {
                line = line_number,
                col = span.cursor_col,
                start_col = span.start_col,
                end_col = span.end_col,
                type = span.type,
            })
        end
    end

    return locations
end

---@param location obs.LinkLocation
---@param line number
---@param col number
---@return boolean
local function location_after_cursor(location, line, col)
    return location.line > line
        or (location.line == line and location.start_col >= col)
end

---@param location obs.LinkLocation
---@param line number
---@param col number
---@return boolean
local function location_before_cursor(location, line, col)
    return location.line < line
        or (location.line == line and location.end_col <= col)
end

---@param location obs.LinkLocation
---@param other obs.LinkLocation?
---@return boolean
local function same_location(location, other)
    return other ~= nil
        and location.line == other.line
        and location.col == other.col
        and location.start_col == other.start_col
        and location.end_col == other.end_col
        and location.type == other.type
end

---@param locations obs.LinkLocation[]
---@param bufnr number
---@param line number
---@param col number
---@return obs.LinkLocation?
local function last_selected_location(locations, bufnr, line, col)
    local last = vim.w.obs_nvim_last_link_location
    if
        type(last) ~= "table"
        or last.bufnr ~= bufnr
        or last.line ~= line
        or last.col ~= col
    then
        return nil
    end

    for _, location in ipairs(locations) do
        if same_location(location, last) then
            return location
        end
    end
end

---@param locations obs.LinkLocation[]
---@param line number
---@param col number
---@param direction 1|-1
---@param skip_location obs.LinkLocation?
---@return obs.LinkLocation
local function next_location(locations, line, col, direction, skip_location)
    if direction > 0 then
        for _, location in ipairs(locations) do
            if
                not same_location(location, skip_location)
                and location_after_cursor(location, line, col)
            then
                return location
            end
        end

        for _, location in ipairs(locations) do
            if not same_location(location, skip_location) then
                return location
            end
        end

        return locations[1]
    end

    for index = #locations, 1, -1 do
        local location = locations[index]
        if
            not same_location(location, skip_location)
            and location_before_cursor(location, line, col)
        then
            return location
        end
    end

    for index = #locations, 1, -1 do
        local location = locations[index]
        if not same_location(location, skip_location) then
            return location
        end
    end

    return locations[#locations]
end

---moves to the next link in the current buffer
---@param count number signed link count
---@param include_markdown boolean include inline Markdown links
function Vault:next_link(count, include_markdown)
    if count == 0 then
        vim.notify("ObsNvimNextLink: count must not be 0", vim.log.levels.WARN)
        return
    end

    local locations = current_buffer_link_locations(include_markdown)
    if #locations == 0 then
        vim.notify "No links found"
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local col = cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()
    local direction = count > 0 and 1 or -1
    local selected_location =
        last_selected_location(locations, bufnr, line, col)

    for _ = 1, math.abs(count) do
        local location =
            next_location(locations, line, col, direction, selected_location)
        selected_location = location
        line = location.line
        col = location.col
    end

    if selected_location ~= nil then
        vim.w.obs_nvim_last_link_location = {
            bufnr = bufnr,
            line = selected_location.line,
            col = selected_location.col,
            start_col = selected_location.start_col,
            end_col = selected_location.end_col,
            type = selected_location.type,
        }
    end

    vim.api.nvim_win_set_cursor(0, { line, col })
end

---checks if this buffer in the vault, usefull in autocommands.
---@return boolean
function Vault:is_current_buffer_in_vault()
    local file_name = vim.api.nvim_buf_get_name(0)
    local home_path = self._home_path:absolute()
    return core.path_has_boundary_prefix(file_name, home_path)
end

---checks if this buffer in the vault, usefull in autocommands.
---@return boolean
function Vault:is_current_buffer_a_note()
    return self:is_current_buffer_in_vault() and vim.bo.filetype == "markdown"
end

---checks if this buffer in the vault, usefull in autocommands.
---@param callback fun()
function Vault:run_if_note(callback)
    if self:is_current_buffer_a_note() then
        return callback()
    else
        vim.notify "Current buffer is not a note"
    end
end

---opens note to edit
---@param name string
function Vault:open_note(name)
    local note = self:get_note(name)
    if note ~= nil then
        note:edit()
    else
        vim.notify("No note for name " .. name)
    end
end

---get note from vault using name of the file
---@param name string
---@return obs.utils.File?
function Vault:get_note(name)
    local notes = self:list_notes()

    for _, note in ipairs(notes) do
        if note:name() == name then
            return note
        end
    end
end

--- Opens daily note to be edited
---@param date_query string?
---@return boolean?
function Vault:open_daily(date_query)
    if date_query and date_query ~= "" then
        return self._journal:open_daily_for(date_query)
    end

    self._journal:open_daily()
end

---@param date_query string?
---@return string?
function Vault:parse_daily_date(date_query)
    return self._journal:parse_daily_date(date_query)
end

---@return string[]
function Vault:list_daily_dates()
    return self._journal:list_daily_dates()
end

---@return string[]
function Vault:list_weekly_dates()
    return self._journal:list_weekly_dates()
end

---@param prefix string?
---@return string[]
function Vault:complete_daily_dates(prefix)
    return self._journal:complete_daily_dates(prefix)
end

--- Opens weekly note to be edited
function Vault:open_weekly()
    self._journal:open_weekly()
end

--- Opens weekly note for an ISO week to be edited
---@param week string
function Vault:open_weekly_for(week)
    self._journal:open_weekly_for(week)
end

---lists notes from vault
---@return obs.utils.File[]
function Vault:list_notes()
    return File.list(self._home_path:expand(), "**/*.md")
end

---lists backlinks to a note using name
---@param name string
---@return obs.utils.File[]
function Vault:list_backlinks(name)
    local note_for_name = self:get_note(name)
    if note_for_name == nil then
        return {}
    end

    ---@type obs.utils.File[]
    local notes_with_backlinks = {}
    local notes = self:list_notes()
    for _, note in ipairs(notes) do
        local text = note:read()
        local links = Link.from_text(text)
        local has_backlink = false
        for _, link in ipairs(links) do
            if link.name == name then
                has_backlink = true
            end
        end
        if has_backlink then
            table.insert(notes_with_backlinks, note)
        end
    end

    return notes_with_backlinks
end

return Vault
