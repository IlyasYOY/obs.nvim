local Path = require "plenary.path"
local File = require "obs.utils.file"

---journal opts
---@class obs.JournalOpts
---@field public home string
---@field public daily_template_name string
---@field public template_name string deprecated way to specifi daily template
---@field public weekly_template_name string
---@field public date_glob string the glob pattern used to list daily notes
---@field public date_provider? fun():string
---@field public week_glob string the glob pattern used to list weekly notes
---@field public week_provider? fun():string

-- daily notes class
---@class obs.Journal
---@field private _templater obs.Templater templater generator
---@field private _date_glob string the glob pattern used to list daily notes
---@field private _date_provider fun(): string the result is used as a file name to the day entry
---@field private _week_glob string the glob pattern used to list weekly notes
---@field private _week_provider fun(): string the result is used as a file name to the week entry
---@field protected _home_path Path home location for daily notes
---@field protected _daily_template_name string template name to be used in daily notes
---@field protected _weekly_template_name string template name to be used in daily notes
local Journal = {}

-- create new Journal
---@param templater obs.Templater
---@param opts obs.JournalOpts?
function Journal:new(templater, opts)
    opts = opts or {}

    self.__index = self
    local journal = setmetatable({}, self)

    journal._templater = templater
    journal._home_path = Path:new(vim.fn.resolve(opts.home))
    journal._daily_template_name = opts.daily_template_name
        or opts.template_name
    journal._weekly_template_name = opts.weekly_template_name
    journal._date_glob = opts.date_glob or "????-??-??"
    journal._date_provider = opts.date_provider
        or function()
            return os.date "%Y-%m-%d"
        end
    journal._week_glob = opts.week_glob or "????-W??"
    journal._week_provider = opts.week_provider
        or function()
            return os.date "%Y-W%W"
        end

    return journal
end

---opens daily note to be edited
function Journal:open_daily()
    local daily_note = self:today(true)
    daily_note:edit()
end

---opens weekly note to be edited
function Journal:open_weekly()
    local weekly_note = self:this_week(true)
    weekly_note:edit()
end

---find in jounal files

-- lists journal daily entries
---@return Array<obs.utils.File>
function Journal:list_dailies()
    local path = self._home_path:expand()
    local files = File.list(path, self._date_glob .. ".md")
    return files
end

-- lists journal weekly entries
---@return Array<obs.utils.File>
function Journal:list_weeklies()
    local path = self._home_path:expand()
    local files = File.list(path, self._week_glob .. ".md")
    return files
end

-- get today note file
---@param create_if_missing boolean?
---@return obs.utils.File
function Journal:today(create_if_missing)
    local filename = self._date_provider()
    ---@type Path
    local path = self._home_path / (filename .. ".md")

    if create_if_missing and not path:exists() then
        path:touch()
        if self._daily_template_name then
            local templated_text = self._templater:process {
                filename = filename,
                template_name = self._daily_template_name,
            }
            path:write(templated_text, "w")
        end
    end

    return File:new(path:expand())
end

-- get this week note file
---@param create_if_missing boolean?
---@return obs.utils.File
function Journal:this_week(create_if_missing)
    local filename = self._week_provider()
    ---@type Path
    local path = self._home_path / (filename .. ".md")

    if create_if_missing and not path:exists() then
        path:touch()
        if self._weekly_template_name then
            local templated_text = self._templater:process {
                filename = filename,
                template_name = self._weekly_template_name,
            }
            path:write(templated_text, "w")
        end
    end

    return File:new(path:expand())
end

return Journal
