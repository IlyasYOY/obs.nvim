local Path = require "obs.utils.path"
local File = require "obs.utils.file"

---journal opts
---@class obs.JournalOpts
---@field public home string
---@field public daily_template_name string
---@field public template_name string deprecated way to specifi daily template
---@field public weekly_template_name string
---@field public date_glob string the glob pattern used to list daily notes
---@field public date_provider? fun():string
---@field public time_provider? fun():number
---@field public week_glob string the glob pattern used to list weekly notes
---@field public week_provider? fun():string

-- daily notes class
---@class obs.Journal
---@field private _templater obs.Templater templater generator
---@field private _date_glob string the glob pattern used to list daily notes
---@field private _date_provider fun(): string the result is used as a file name to the day entry
---@field private _time_provider fun(): number
---@field private _week_glob string the glob pattern used to list weekly notes
---@field private _week_provider fun(): string the result is used as a file name to the week entry
---@field protected _home_path obs.utils.Path home location for daily notes
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
    journal._time_provider = opts.time_provider or os.time
    journal._date_provider = opts.date_provider
        or function()
            return os.date("%Y-%m-%d", journal._time_provider())
        end
    journal._week_glob = opts.week_glob or "????-W??"
    journal._week_provider = opts.week_provider
        or function()
            return os.date("%G-W%V", journal._time_provider())
        end

    return journal
end

---@param time number
---@return string
local function format_date(time)
    return os.date("%Y-%m-%d", time)
end

---@param year number
---@param month number
---@param day number
---@return number?
local function validated_date_time(year, month, day)
    local time = os.time {
        year = year,
        month = month,
        day = day,
        hour = 12,
    }
    if not time then
        return nil
    end

    local date = os.date("*t", time)
    if date.year ~= year or date.month ~= month or date.day ~= day then
        return nil
    end

    return time
end

---@param base_time number
---@param offset_days number
---@return string
local function format_relative_date(base_time, offset_days)
    local base_date = os.date("*t", base_time)
    local time = os.time {
        year = base_date.year,
        month = base_date.month,
        day = base_date.day + offset_days,
        hour = 12,
    }
    return format_date(time)
end

---@param value string?
---@return string?
function Journal:parse_daily_date(value)
    if not value or value == "" then
        return self._date_provider()
    end

    local normalized = vim.trim(value):lower()
    if normalized == "" or normalized == "today" then
        return self._date_provider()
    end
    if normalized == "tomorrow" then
        return format_relative_date(self._time_provider(), 1)
    end
    if normalized == "yesterday" then
        return format_relative_date(self._time_provider(), -1)
    end

    local year, month, day = normalized:match "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"
    if year then
        local time =
            validated_date_time(tonumber(year), tonumber(month), tonumber(day))
        if time then
            return format_date(time)
        end
        return nil
    end

    local past_days = normalized:match "^(%d+)%s+days?%s+ago$"
    if past_days then
        return format_relative_date(self._time_provider(), -tonumber(past_days))
    end

    local future_days = normalized:match "^in%s+(%d+)%s+days?$"
    if future_days then
        return format_relative_date(
            self._time_provider(),
            tonumber(future_days)
        )
    end

    return nil
end

---opens daily note to be edited
function Journal:open_daily()
    local daily_note = self:today(true)
    daily_note:edit()
end

---opens daily note for a date query to be edited
---@param date_query string?
---@return boolean
function Journal:open_daily_for(date_query)
    local daily_note = self:daily_for(date_query, true)
    if not daily_note then
        vim.notify("Invalid daily note date: " .. tostring(date_query))
        return false
    end

    daily_note:edit()
    return true
end

---opens weekly note to be edited
function Journal:open_weekly()
    local weekly_note = self:this_week(true)
    weekly_note:edit()
end

---opens weekly note for an ISO week to be edited
---@param week string
function Journal:open_weekly_for(week)
    local weekly_note = self:week_for(week, true)
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

---@return string[]
function Journal:list_daily_dates()
    local results = {}
    for _, file in ipairs(self:list_dailies()) do
        local name = file:name()
        if name then
            results[#results + 1] = name
        end
    end

    table.sort(results)
    return results
end

---@param prefix string?
---@return string[]
function Journal:complete_daily_dates(prefix)
    prefix = prefix or ""

    local results = {}
    for _, name in ipairs(self:list_daily_dates()) do
        if name and string.find(name, prefix, 1, true) == 1 then
            results[#results + 1] = name
        end
    end

    return results
end

-- lists journal weekly entries
---@return Array<obs.utils.File>
function Journal:list_weeklies()
    local path = self._home_path:expand()
    local files = File.list(path, self._week_glob .. ".md")
    return files
end

---@return string[]
function Journal:list_weekly_dates()
    local results = {}
    for _, file in ipairs(self:list_weeklies()) do
        local name = file:name()
        if name then
            results[#results + 1] = name
        end
    end

    table.sort(results)
    return results
end

-- get today note file
---@param create_if_missing boolean?
---@return obs.utils.File
function Journal:today(create_if_missing)
    return self:_daily_by_filename(self._date_provider(), create_if_missing)
end

-- get daily note file for a date query
---@param date_query string?
---@param create_if_missing boolean?
---@return obs.utils.File?
function Journal:daily_for(date_query, create_if_missing)
    local filename = self:parse_daily_date(date_query)
    if not filename then
        return nil
    end

    return self:_daily_by_filename(filename, create_if_missing)
end

---@param filename string
---@param create_if_missing boolean?
---@return obs.utils.File
function Journal:_daily_by_filename(filename, create_if_missing)
    ---@type obs.utils.Path
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
    return self:week_for(self._week_provider(), create_if_missing)
end

-- get weekly note file for an ISO week
---@param week string
---@param create_if_missing boolean?
---@return obs.utils.File
function Journal:week_for(week, create_if_missing)
    local filename = week
    ---@type obs.utils.Path
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
