local obs = require "obs"

describe("commands", function()
    after_each(function()
        obs.vault = nil
    end)

    describe("ObsNvimDailyNote", function()
        it("accepts optional arguments", function()
            local command = vim.api.nvim_get_commands({}).ObsNvimDailyNote

            assert.are.equal("*", command.nargs)
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

        it("passes date text to the vault", function()
            local received_query
            obs.vault = {
                open_daily = function(_, date_query)
                    received_query = date_query
                end,
            }

            vim.cmd "ObsNvimDailyNote 2 days ago"

            assert.are.equal("2 days ago", received_query)
        end)
    end)
end)
