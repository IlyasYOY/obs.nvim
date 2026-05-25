---@class obs.Calendar
---@field private _vault obs.Vault
---@field private _year number
---@field private _month number
---@field private _day number
---@field private _buf number?
---@field private _win number?
---@field private _show_help boolean
---@field private _day_cells table<string, { line: number, col: number }>
---@field private _marked_dates table<string, boolean>
---@field private _week_rows table<number, string>
---@field private _marked_weeks table<number, boolean>
local Calendar = {}
Calendar.__index = Calendar

local ns = vim.api.nvim_create_namespace "obs-calendar"

local month_names = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

local weekday_cells = {
    "Mo ",
    "Tu ",
    "We ",
    "Th ",
    "Fr ",
    "Sa ",
    "Su ",
}

local day_grid_offset = 3
local day_grid_width = 27
local calendar_width = day_grid_offset + day_grid_width

---@param text string
---@param width number
---@return string
local function center(text, width)
    local padding = width - #text
    if padding <= 0 then
        return text
    end

    local left = math.floor(padding / 2)
    return string.rep(" ", left) .. text .. string.rep(" ", padding - left)
end

---@param year number
---@param month number
---@param day number
---@return string
local function format_date(year, month, day)
    return ("%04d-%02d-%02d"):format(year, month, day)
end

---@param date string
---@return number?, number?, number?
local function parse_date(date)
    if type(date) ~= "string" then
        return nil, nil, nil
    end

    local year, month, day = date:match "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"
    if not year then
        return nil, nil, nil
    end

    return tonumber(year), tonumber(month), tonumber(day)
end

---@param year number
---@param month number
---@return number
local function days_in_month(year, month)
    local time = os.time {
        year = year,
        month = month + 1,
        day = 0,
        hour = 12,
    }
    return tonumber(os.date("%d", time)) or 31
end

---@param year number
---@param month number
---@param day number
---@return number
local function weekday_column(year, month, day)
    local time = os.time {
        year = year,
        month = month,
        day = day,
        hour = 12,
    }
    local weekday = os.date("*t", time).wday
    return ((weekday + 5) % 7) + 1
end

---@param year number
---@param month number
---@param day number
---@return number
local function date_time(year, month, day)
    return os.time {
        year = year,
        month = month,
        day = day,
        hour = 12,
    }
end

---@param year number
---@param month number
---@param day number
---@return number, number, number
local function normalized_date(year, month, day)
    local time = os.time {
        year = year,
        month = month,
        day = day,
        hour = 12,
    }
    local date = os.date("*t", time)
    return date.year, date.month, date.day
end

---@param year number
---@param month number
---@param day number
---@return string
local function journal_week_id(year, month, day)
    local time = date_time(year, month, day)
    return ("%04d-W%s"):format(year, os.date("%V", time))
end

---@param vault obs.Vault
---@param initial_date string
---@return obs.Calendar
function Calendar:new(vault, initial_date)
    local year, month, day = parse_date(initial_date)
    assert(year and month and day, "initial_date must be YYYY-MM-DD")

    return setmetatable({
        _vault = vault,
        _year = year,
        _month = month,
        _day = day,
        _show_help = false,
        _day_cells = {},
        _marked_dates = {},
        _week_rows = {},
        _marked_weeks = {},
    }, self)
end

---@param vault obs.Vault
---@param date_query string?
---@return obs.Calendar?
function Calendar.open(vault, date_query)
    local initial_date = vault:parse_daily_date(date_query)
    if not initial_date then
        vim.notify("Invalid daily note date: " .. tostring(date_query))
        return nil
    end

    local year, month, day = parse_date(initial_date)
    if not (year and month and day) then
        vim.notify(
            "ObsNvimDailyNote!: calendar requires YYYY-MM-DD daily filenames, got "
                .. tostring(initial_date)
                .. ".",
            vim.log.levels.WARN
        )
        return nil
    end

    local calendar = Calendar:new(vault, initial_date)
    calendar:show()
    return calendar
end

---@return string
function Calendar:selected_date()
    return format_date(self._year, self._month, self._day)
end

---@return string
function Calendar:selected_week()
    local selected_cell = self._day_cells[self:selected_date()]
    if selected_cell and self._week_rows[selected_cell.line] then
        return self._week_rows[selected_cell.line]
    end

    local column = weekday_column(self._year, self._month, self._day)
    return journal_week_id(self._year, self._month, self._day - column + 1)
end

---@return table<string, boolean>
function Calendar:_existing_date_set()
    local existing_dates = {}
    for _, date in ipairs(self._vault:list_daily_dates()) do
        existing_dates[date] = true
    end
    return existing_dates
end

---@return table<string, boolean>
function Calendar:_existing_week_set()
    local existing_weeks = {}
    for _, week in ipairs(self._vault:list_weekly_dates()) do
        existing_weeks[week] = true
    end
    return existing_weeks
end

---@return string[]
function Calendar:_lines()
    local existing_dates = self:_existing_date_set()
    local existing_weeks = self:_existing_week_set()
    local lines = {
        center(
            month_names[self._month] .. " " .. tostring(self._year),
            calendar_width
        ),
        "Wk " .. table.concat(weekday_cells, " "),
    }
    self._day_cells = {}
    self._marked_dates = {}
    self._week_rows = {}
    self._marked_weeks = {}

    local first_column = weekday_column(self._year, self._month, 1)
    local month_days = days_in_month(self._year, self._month)
    local day = 1

    for week = 1, 6 do
        local cells = {}
        local week_monday = 2 - first_column + ((week - 1) * 7)
        local week_id = journal_week_id(self._year, self._month, week_monday)
        for column = 1, 7 do
            if (week == 1 and column < first_column) or day > month_days then
                cells[#cells + 1] = "   "
            else
                local date = format_date(self._year, self._month, day)
                local marker = existing_dates[date] and "*" or " "
                self._marked_dates[date] = existing_dates[date] or false
                cells[#cells + 1] = ("%2d%s"):format(day, marker)
                self._day_cells[date] = {
                    line = #lines + 1,
                    col = day_grid_offset + ((column - 1) * 4),
                }
                day = day + 1
            end
        end

        local line = #lines + 1
        local week_marker = existing_weeks[week_id] and "*" or " "
        self._week_rows[line] = week_id
        self._marked_weeks[line] = existing_weeks[week_id] or false
        lines[#lines + 1] = week_id:sub(-2)
            .. week_marker
            .. table.concat(cells, " ")
    end

    if self._show_help then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "? mappings"
        lines[#lines + 1] = "h/l day    j/k week"
        lines[#lines + 1] = "J/K month  <CR> open"
        lines[#lines + 1] = "w weekly   q/Esc close"
    end

    return lines
end

---@param lines string[]
---@return number
local function max_width(lines)
    local width = calendar_width
    for _, line in ipairs(lines) do
        width = math.max(width, #line)
    end
    return width
end

---@param width number
---@param height number
---@return number, number
local function centered_position(width, height)
    local row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0)
    local col = math.max(math.floor((vim.o.columns - width) / 2), 0)
    return row, col
end

function Calendar:_highlight()
    if not self._buf then
        return
    end

    vim.api.nvim_buf_clear_namespace(self._buf, ns, 0, -1)

    for date, cell in pairs(self._day_cells) do
        if date == self:selected_date() then
            vim.api.nvim_buf_add_highlight(
                self._buf,
                ns,
                "Visual",
                cell.line - 1,
                cell.col,
                cell.col + 3
            )
        elseif self._marked_dates[date] then
            vim.api.nvim_buf_add_highlight(
                self._buf,
                ns,
                "Special",
                cell.line - 1,
                cell.col + 2,
                cell.col + 3
            )
        end
    end

    for line, marked in pairs(self._marked_weeks) do
        if marked then
            vim.api.nvim_buf_add_highlight(
                self._buf,
                ns,
                "Special",
                line - 1,
                2,
                3
            )
        end
    end

    local selected_cell = self._day_cells[self:selected_date()]
    if self._win and selected_cell and vim.api.nvim_win_is_valid(self._win) then
        vim.api.nvim_win_set_cursor(self._win, {
            selected_cell.line,
            selected_cell.col,
        })
    end
end

function Calendar:render()
    if not self._buf then
        return
    end

    local lines = self:_lines()
    local width = max_width(lines)
    local height = #lines

    vim.bo[self._buf].modifiable = true
    vim.api.nvim_buf_set_lines(self._buf, 0, -1, false, lines)
    vim.bo[self._buf].modifiable = false

    if self._win and vim.api.nvim_win_is_valid(self._win) then
        local row, col = centered_position(width, height)
        vim.api.nvim_win_set_config(self._win, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
        })
    end

    self:_highlight()
end

function Calendar:_map_keys()
    if not self._buf then
        return
    end

    local opts = {
        buffer = self._buf,
        nowait = true,
        silent = true,
    }

    vim.keymap.set("n", "h", function()
        self:move_days(-1)
    end, opts)
    vim.keymap.set("n", "l", function()
        self:move_days(1)
    end, opts)
    vim.keymap.set("n", "j", function()
        self:move_days(7)
    end, opts)
    vim.keymap.set("n", "k", function()
        self:move_days(-7)
    end, opts)
    vim.keymap.set("n", "J", function()
        self:move_months(1)
    end, opts)
    vim.keymap.set("n", "K", function()
        self:move_months(-1)
    end, opts)
    vim.keymap.set("n", "<CR>", function()
        self:open_selected()
    end, opts)
    vim.keymap.set("n", "w", function()
        self:open_selected_week()
    end, opts)
    vim.keymap.set("n", "q", function()
        self:close()
    end, opts)
    vim.keymap.set("n", "<Esc>", function()
        self:close()
    end, opts)
    vim.keymap.set("n", "?", function()
        self:toggle_help()
    end, opts)
end

---@return obs.Calendar
function Calendar:show()
    self._buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self._buf].bufhidden = "wipe"
    vim.bo[self._buf].buftype = "nofile"
    vim.bo[self._buf].filetype = "obs-calendar"
    vim.bo[self._buf].swapfile = false

    local lines = self:_lines()
    local width = max_width(lines)
    local height = #lines
    local row, col = centered_position(width, height)

    self._win = vim.api.nvim_open_win(self._buf, true, {
        border = "rounded",
        col = col,
        height = height,
        relative = "editor",
        row = row,
        style = "minimal",
        width = width,
    })
    self:_map_keys()
    self:render()
    return self
end

function Calendar:close()
    if self._win and vim.api.nvim_win_is_valid(self._win) then
        vim.api.nvim_win_close(self._win, true)
    end
    if self._buf and vim.api.nvim_buf_is_valid(self._buf) then
        pcall(vim.api.nvim_buf_delete, self._buf, {
            force = true,
        })
    end

    self._win = nil
    self._buf = nil
end

---@param offset number
function Calendar:move_days(offset)
    self._year, self._month, self._day =
        normalized_date(self._year, self._month, self._day + offset)
    self:render()
end

---@param offset number
function Calendar:move_months(offset)
    local year, month = normalized_date(self._year, self._month + offset, 1)
    self._year = year
    self._month = month
    self._day = math.min(self._day, days_in_month(self._year, self._month))
    self:render()
end

function Calendar:toggle_help()
    self._show_help = not self._show_help
    self:render()
end

function Calendar:open_selected()
    local date = self:selected_date()
    self:close()
    self._vault:open_daily(date)
end

function Calendar:open_selected_week()
    local week = self:selected_week()
    self:close()
    self._vault:open_weekly_for(week)
end

return Calendar
