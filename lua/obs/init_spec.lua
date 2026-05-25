local Calendar = require "obs.calendar"
local obs = require "obs"

describe("commands", function()
    local original_notify = vim.notify
    local original_calendar_open = Calendar.open

    after_each(function()
        obs.vault = nil
        Calendar.open = original_calendar_open
        vim.notify = original_notify
    end)

    describe("ObsNvimDailyNote", function()
        it("accepts optional arguments", function()
            local command = vim.api.nvim_get_commands({}).ObsNvimDailyNote

            assert.are.equal("*", command.nargs)
        end)

        it("accepts count", function()
            local command = vim.api.nvim_get_commands({}).ObsNvimDailyNote

            assert.are.equal("0", command.count)
        end)

        it("accepts bang", function()
            local command = vim.api.nvim_get_commands({}).ObsNvimDailyNote

            assert.is_true(command.bang)
        end)

        it("completes daily dates through the vault", function()
            local received_prefix
            obs.vault = {
                complete_daily_dates = function(_, prefix)
                    received_prefix = prefix
                    return { "2024-02-14" }
                end,
            }

            local result =
                vim.fn.getcompletion("ObsNvimDailyNote 2024-02", "cmdline")

            assert.are.equal("2024-02", received_prefix)
            assert.same({ "2024-02-14" }, result)
        end)

        it("opens today's daily note without arguments", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "ObsNvimDailyNote"

            assert.are.equal("", received_query)
        end)

        it("passes exact date text to the vault", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "ObsNvimDailyNote 2024-02-14"

            assert.are.equal("2024-02-14", received_query)
        end)

        it("passes relative date text to the vault", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "ObsNvimDailyNote 2 days ago"

            assert.are.equal("2 days ago", received_query)
        end)

        it("passes prefixed count as future day query", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "10ObsNvimDailyNote"

            assert.are.equal("in 10 days", received_query)
        end)

        it("passes argument count as future day query", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "ObsNvimDailyNote 10"

            assert.are.equal("in 10 days", received_query)
        end)

        it("opens calendar for bang without arguments", function()
            local received_vault
            local received_query
            obs.vault = {}
            Calendar.open = function(vault, date_query)
                received_vault = vault
                received_query = date_query
            end

            vim.cmd "ObsNvimDailyNote!"

            assert.are.equal(obs.vault, received_vault)
            assert.are.equal("", received_query)
        end)

        it("opens calendar focused on exact date text", function()
            local received_query
            obs.vault = {}
            Calendar.open = function(_, date_query)
                received_query = date_query
            end

            vim.cmd "ObsNvimDailyNote! 2024-02-14"

            assert.are.equal("2024-02-14", received_query)
        end)

        it("opens calendar focused on count date", function()
            local received_query
            obs.vault = {}
            Calendar.open = function(_, date_query)
                received_query = date_query
            end

            vim.cmd "10ObsNvimDailyNote!"

            assert.are.equal("in 10 days", received_query)
        end)

        it(
            "warns and skips opening when count is combined with date text",
            function()
                local opened = false
                local notifications = {}
                obs.vault = {
                    open_daily = function()
                        opened = true
                    end,
                }
                vim.notify = function(message, level)
                    notifications[#notifications + 1] = {
                        level = level,
                        message = message,
                    }
                end

                vim.cmd "10ObsNvimDailyNote today"
                vim.cmd "10ObsNvimDailyNote 2024-02-14"
                vim.cmd "ObsNvimDailyNote 10 today"
                vim.cmd "ObsNvimDailyNote 10 tomorrow"

                assert.is_false(opened)
                assert.same({
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                }, notifications)
            end
        )

        it(
            "warns and skips calendar when prefixed count is combined with date text",
            function()
                local opened = false
                local notifications = {}
                obs.vault = {}
                Calendar.open = function()
                    opened = true
                end
                vim.notify = function(message, level)
                    notifications[#notifications + 1] = {
                        level = level,
                        message = message,
                    }
                end

                vim.cmd "10ObsNvimDailyNote! 2024-02-14"
                vim.cmd "ObsNvimDailyNote! 10 today"

                assert.is_false(opened)
                assert.same({
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                    {
                        level = vim.log.levels.WARN,
                        message = "ObsNvimDailyNote: use either a count or a date, not both.",
                    },
                }, notifications)
            end
        )
    end)
end)
