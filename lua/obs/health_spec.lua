local Path = require "plenary.path"
local health = require "obs.health"
local obs = require "obs"
local spec = require "obs.utils.spec"
local utils = require "obs.utils"

local function capture_health()
    local reports = {}
    local captured = {}
    for _, level in ipairs { "start", "ok", "warn", "error", "info" } do
        captured[level] = function(message, advice)
            reports[#reports + 1] = {
                level = level,
                message = message,
                advice = advice,
            }
        end
    end
    return captured, reports
end

local function has_report(reports, level, message)
    for _, report in ipairs(reports) do
        if
            report.level == level
            and string.find(report.message, message, 1, true)
        then
            return true
        end
    end
    return false
end

local function assert_report(reports, level, message)
    assert.is_true(
        has_report(reports, level, message),
        "expected " .. level .. " report containing '" .. message .. "'"
    )
end

describe("health", function()
    local original_health
    local reports

    before_each(function()
        local captured_health
        captured_health, reports = capture_health()
        original_health = vim.health
        vim.health = captured_health
        obs.vault = nil
    end)

    after_each(function()
        vim.health = original_health
        obs.vault = nil
    end)

    it("warns when setup was not called", function()
        health.check()

        assert_report(reports, "start", "obs.nvim")
        assert_report(reports, "ok", "obs.nvim is available")
        assert_report(reports, "ok", "plenary.nvim is available")
        assert_report(reports, "warn", "obs.setup() has not been called")
    end)

    describe("configured vault", function()
        local vault_home = spec.temp_dir_fixture()
        local templates_home = spec.temp_dir_fixture()
        local journal_home = spec.temp_dir_fixture()

        it("reports vault, template, and journal details", function()
            local note = vault_home.path / "note.md"
            local daily_template = templates_home.path / "daily.md"
            local weekly_template = templates_home.path / "weekly.md"
            local idea_template = templates_home.path / "idea.md"
            local daily_note = journal_home.path / "2024-01-02.md"
            local weekly_note = journal_home.path / "2024-W03.md"

            note:touch {}
            daily_template:touch {}
            weekly_template:touch {}
            idea_template:touch {}
            daily_note:touch {}
            weekly_note:touch {}

            obs.setup {
                vault_home = vault_home.path:expand(),
                vault_name = "Notes",
                templater = {
                    home = templates_home.path:expand(),
                },
                journal = {
                    home = journal_home.path:expand(),
                    daily_template_name = "daily",
                    weekly_template_name = "weekly",
                },
            }

            health.check()

            assert_report(reports, "ok", "obs.setup() has been called")
            assert_report(reports, "info", "Vault name: Notes")
            assert_report(reports, "ok", "Vault directory exists")
            assert_report(reports, "info", "Markdown notes: 1")
            assert_report(reports, "ok", "Templates directory exists")
            assert_report(reports, "info", "Templates: daily, idea, weekly")
            assert_report(reports, "ok", "Daily template is available: daily")
            assert_report(reports, "ok", "Weekly template is available: weekly")
            assert_report(reports, "ok", "Journal directory exists")
            assert_report(reports, "info", "Daily notes: 1")
            assert_report(reports, "info", "Weekly notes: 1")
        end)

        it("warns for missing template and journal directories", function()
            local templates_path = (
                vault_home.path / ("missing-templates-" .. utils.uuid())
            )
            local journal_path = (
                vault_home.path / ("missing-journal-" .. utils.uuid())
            )

            obs.setup {
                vault_home = vault_home.path:expand(),
                templater = {
                    home = templates_path:expand(),
                },
                journal = {
                    home = journal_path:expand(),
                },
            }

            health.check()

            assert_report(reports, "warn", "Templates directory does not exist")
            assert_report(reports, "warn", "Journal directory does not exist")
        end)

        it("warns for configured templates that are not available", function()
            (templates_home.path / "other.md"):touch {}

            obs.setup {
                vault_home = vault_home.path:expand(),
                templater = {
                    home = templates_home.path:expand(),
                },
                journal = {
                    home = journal_home.path:expand(),
                    daily_template_name = "daily",
                    weekly_template_name = "weekly",
                },
            }

            health.check()

            assert_report(reports, "warn", "Daily template is missing: daily")
            assert_report(reports, "warn", "Weekly template is missing: weekly")
        end)

        it("limits long template lists", function()
            for index = 1, 21 do
                local name = string.format("template-%02d.md", index)
                local template = templates_home.path / name
                template:touch {}
            end

            obs.setup {
                vault_home = vault_home.path:expand(),
                templater = {
                    home = templates_home.path:expand(),
                },
                journal = {
                    home = journal_home.path:expand(),
                },
            }

            health.check()

            assert_report(reports, "info", "(1 more)")
        end)
    end)

    it("errors when the configured vault path does not exist", function()
        local vault_path = Path:new("/tmp/lua-" .. utils.uuid())

        obs.setup {
            vault_home = vault_path:expand(),
        }

        health.check()

        assert_report(reports, "error", "Vault directory does not exist")
    end)
end)
