local Calendar = require "obs.calendar"

local calendars = {}
local original_notify = vim.notify

---@param opts { parsed_date: string?, daily_dates: string[]?, weekly_dates: string[]? }
---@return table
local function make_vault(opts)
    opts = opts or {}

    return {
        opened_date = nil,
        opened_week = nil,
        parsed_query = nil,
        list_daily_dates = function()
            return opts.daily_dates or {}
        end,
        list_weekly_dates = function()
            return opts.weekly_dates or {}
        end,
        open_daily = function(vault, date_query)
            vault.opened_date = date_query
        end,
        open_weekly_for = function(vault, week)
            vault.opened_week = week
        end,
        parse_daily_date = function(vault, date_query)
            vault.parsed_query = date_query
            return opts.parsed_date
        end,
    }
end

---@param vault table
---@param date_query string?
---@return obs.Calendar
local function open_calendar(vault, date_query)
    local calendar = Calendar.open(vault, date_query)
    calendars[#calendars + 1] = calendar
    return calendar
end

---@param calendar obs.Calendar
---@return string[]
local function lines(calendar)
    return vim.api.nvim_buf_get_lines(calendar._buf, 0, -1, false)
end

---@param values string[]
---@param value string
---@return boolean
local function contains(values, value)
    for _, item in ipairs(values) do
        if item == value then
            return true
        end
    end

    return false
end

describe("calendar", function()
    after_each(function()
        for _, calendar in ipairs(calendars) do
            if calendar then
                calendar:close()
            end
        end
        calendars = {}
        vim.notify = original_notify
    end)

    it("renders requested month", function()
        local calendar = open_calendar(
            make_vault {
                parsed_date = "2024-02-14",
            },
            "today"
        )

        assert.are.equal("today", calendar._vault.parsed_query)
        assert.truthy(lines(calendar)[1]:find("February 2024", 1, true))
    end)

    it("renders aligned day cells and marks existing notes", function()
        local calendar = open_calendar(make_vault {
            daily_dates = {
                "2024-02-01",
                "2024-02-12",
            },
            parsed_date = "2024-02-14",
        })
        local rendered_lines = lines(calendar)

        for i = 1, 8 do
            assert.are.equal(30, #rendered_lines[i])
        end
        for i = 2, 8 do
            assert.are.equal(27, #rendered_lines[i]:sub(4))
        end

        assert.are.equal("Wk Mo  Tu  We  Th  Fr  Sa  Su ", rendered_lines[2])
        assert.are.equal("05 ", rendered_lines[3]:sub(1, 3))
        assert.are.equal("07 ", rendered_lines[5]:sub(1, 3))
        assert.are.equal(16, rendered_lines[3]:find(" 1*", 1, true))
        assert.truthy(rendered_lines[3]:find(" 2 ", 1, true))
        assert.are.equal(4, rendered_lines[5]:find("12*", 1, true))
        assert.truthy(rendered_lines[5]:find("13 ", 1, true))
    end)

    it("marks existing weekly notes in the week column", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2024-02-14",
            weekly_dates = {
                "2024-W05",
                "2024-W07",
            },
        })
        local rendered_lines = lines(calendar)

        assert.are.equal("05*", rendered_lines[3]:sub(1, 3))
        assert.are.equal("06 ", rendered_lines[4]:sub(1, 3))
        assert.are.equal("07*", rendered_lines[5]:sub(1, 3))
        assert.are.equal(16, rendered_lines[3]:find(" 1 ", 1, true))
        assert.are.equal(30, #rendered_lines[3])
    end)

    it("renders ISO week markers across year boundaries", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2021-01-01",
            weekly_dates = {
                "2021-W53",
            },
        })
        local rendered_lines = lines(calendar)

        assert.are.equal("53*", rendered_lines[3]:sub(1, 3))
        assert.are.equal("01 ", rendered_lines[4]:sub(1, 3))
    end)

    it("moves between months and clamps selected day", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2024-01-31",
        })

        calendar:move_months(1)

        assert.are.equal("2024-02-29", calendar:selected_date())
        assert.truthy(lines(calendar)[1]:find("February 2024", 1, true))

        calendar:move_months(-1)

        assert.are.equal("2024-01-29", calendar:selected_date())
        assert.truthy(lines(calendar)[1]:find("January 2024", 1, true))
    end)

    it("toggles mapping help", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2024-02-14",
        })

        assert.is_false(contains(lines(calendar), "? mappings"))

        calendar:toggle_help()

        assert.is_true(contains(lines(calendar), "? mappings"))
        assert.is_true(contains(lines(calendar), "h/l day    j/k week"))
        assert.is_true(contains(lines(calendar), "J/K month  <CR> open"))
        assert.is_true(contains(lines(calendar), "w weekly   q/Esc close"))

        calendar:toggle_help()

        assert.is_false(contains(lines(calendar), "? mappings"))
    end)

    it("maps month navigation and help keys", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2024-02-14",
        })
        local lhs = {}
        for _, mapping in
            ipairs(vim.api.nvim_buf_get_keymap(calendar._buf, "n"))
        do
            lhs[#lhs + 1] = mapping.lhs
        end

        assert.is_true(contains(lhs, "J"))
        assert.is_true(contains(lhs, "K"))
        assert.is_true(contains(lhs, "w"))
        assert.is_true(contains(lhs, "?"))
    end)

    it("opens selected date through the vault", function()
        local vault = make_vault {
            parsed_date = "2024-02-14",
        }
        local calendar = open_calendar(vault)

        calendar:move_days(1)
        calendar:open_selected()

        assert.are.equal("2024-02-15", vault.opened_date)
    end)

    it("opens selected row weekly note through the vault", function()
        local vault = make_vault {
            parsed_date = "2024-02-14",
        }
        local calendar = open_calendar(vault)

        calendar:open_selected_week()

        assert.are.equal("2024-W07", vault.opened_week)
    end)

    it("opens selected row weekly note across year boundaries", function()
        local vault = make_vault {
            parsed_date = "2021-01-01",
        }
        local calendar = open_calendar(vault)

        calendar:open_selected_week()

        assert.are.equal("2021-W53", vault.opened_week)
    end)

    it("keeps j and k moving by one week", function()
        local calendar = open_calendar(make_vault {
            parsed_date = "2024-02-14",
        })

        vim.api.nvim_feedkeys("j", "x", false)
        assert.are.equal("2024-02-21", calendar:selected_date())

        vim.api.nvim_feedkeys("k", "x", false)
        assert.are.equal("2024-02-14", calendar:selected_date())
    end)

    it("warns and does not open for invalid initial date", function()
        local notifications = {}
        local vault = make_vault {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        local calendar = Calendar.open(vault, "last friday")

        assert.is_nil(calendar)
        assert.same({
            "Invalid daily note date: last friday",
        }, notifications)
    end)

    it("warns and does not open for custom daily filenames", function()
        local notifications = {}
        local vault = make_vault {
            parsed_date = "daily-2024-02-14",
        }
        vim.notify = function(message, level)
            notifications[#notifications + 1] = {
                level = level,
                message = message,
            }
        end

        local calendar = Calendar.open(vault, "")

        assert.is_nil(calendar)
        assert.same({
            {
                level = vim.log.levels.WARN,
                message = "ObsNvimDailyNote!: calendar requires YYYY-MM-DD daily filenames, got daily-2024-02-14.",
            },
        }, notifications)
    end)
end)
