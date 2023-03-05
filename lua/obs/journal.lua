local Path = require "plenary.path"
local File = require "coredor.file"
local telescope = require "obs.telescope"

---journal opts
---@class obs.JournalOpts
---@field public home string
---@field public template_name string
---@field public date_provider? fun():string

-- daily notes class
---@class obs.Journal
---@field private _templater obs.Templater templater generator
---@field private _date_provider fun(): string the result is used as a file name to the entry
---@field protected _home_path Path home location for daily notes
---@field protected _template_name string template name to be used in daily notes
local Journal = {}

-- create new Journal
---@param templater obs.Templater
---@param opts obs.JournalOpts?
function Journal:new(templater, opts)
    opts = opts or {}

    self.__index = self
    local journal = setmetatable({}, self)

    journal._templater = templater
    journal._home_path = Path:new(opts.home)
    journal._template_name = opts.template_name
    journal._date_provider = opts.date_provider
        or function()
            return os.date "%Y-%m-%d"
        end

    return journal
end

---opens dauly notes to be edited
function Journal:open_daily()
    local daily_note = self:today(true)
    vim.fn.execute("edit " .. daily_note:path())
end

---find in daily note files
function Journal:find_journal()
    return telescope.find_files("Dailies", self._home_path:expand())
end

-- lists journal entries
---@return Array<coredor.File>
function Journal:list_dailies()
    local path = self._home_path:expand()
    local files = File.list(path, "????-??-??.md")
    return files
end

-- get today note file
---@param create_if_missing boolean?
---@return coredor.File
function Journal:today(create_if_missing)
    local filename = self._date_provider()
    ---@type Path
    local path = self._home_path / (filename .. ".md")

    if create_if_missing and not path:exists() then
        path:touch()
        if self._template_name then
            local templated_text = self._templater:process {
                filename = filename,
                template_name = self._template_name,
            }
            path:write(templated_text, "w")
        end
    end

    return File:new(path:expand())
end

return Journal
