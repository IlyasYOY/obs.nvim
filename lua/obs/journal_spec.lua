local Path = require "obs.utils.path"
local Journal = require "obs.journal"
local Templater = require "obs.templater"

local spec_utils = require "obs.utils.spec"
local core = require "obs.utils"

local function journal_fixture()
    local result = {}

    local journal_dir_path = spec_utils.temp_dir_fixture()
    local templates_dir_path = spec_utils.temp_dir_fixture()

    result.journal_dir_path = journal_dir_path
    result.templates_dir_path = templates_dir_path

    before_each(function()
        local templater =
            Templater:new { home = templates_dir_path.path:expand() }
        result.templater = templater

        result.copy_with_opts = function(opts)
            opts = opts or {}

            result.journal = Journal:new(templater, {
                home = journal_dir_path.path:expand(),
                date_provider = opts.date_provider,
                time_provider = opts.time_provider,
                week_provider = opts.week_provider,
                daily_template_name = opts.daily_template_name,
                template_name = opts.template_name,
                weekly_template_name = opts.weekly_template_name,
                date_glob = opts.date_glob,
                week_glob = opts.week_glob,
            })
        end

        result.copy_with_opts()
    end)

    return result
end

describe("journal", function()
    local test_state = journal_fixture()

    local function time_for(year, month, day)
        return os.time {
            year = year,
            month = month,
            day = day,
            hour = 12,
        }
    end

    describe("weekly", function()
        it("get", function()
            test_state.copy_with_opts {
                week_provider = function()
                    return "2023-W04"
                end,
            }

            local result = test_state.journal:this_week()

            assert.are.equal("2023-W04", result:name(), "file name is wrong")
            assert.is_true(
                core.string_has_suffix(result:path(), ".md"),
                "file type is wrong"
            )
        end)

        it("get and not create file", function()
            test_state.copy_with_opts {
                week_provider = function()
                    return "2023-W04"
                end,
            }

            local result = test_state.journal:this_week()

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_false(path:exists(), "file was created")
        end)

        it("get and create file", function()
            test_state.copy_with_opts {
                week_provider = function()
                    return "2022-W04"
                end,
            }

            local result = test_state.journal:this_week(true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_true(path:exists(), "file was not created")
        end)

        it("create matching template", function()
            test_state.copy_with_opts {
                week_provider = function()
                    return "2022-W07"
                end,
                weekly_template_name = "weekly",
            }

            ---@type obs.utils.Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "weekly.md"

            local expected_text = "this is example template 2022-W07"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:this_week(true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())
            local resulting_text = path:read()

            assert.are.equal(
                resulting_text,
                expected_text,
                string.format(
                    "Expected mathing template '%s' but was '%s'",
                    expected_text,
                    resulting_text
                )
            )
        end)

        it("gets specific week", function()
            local result = test_state.journal:week_for "2024-W07"

            assert.are.equal("2024-W07", result:name(), "file name is wrong")
            assert.is_true(
                core.string_has_suffix(result:path(), ".md"),
                "file type is wrong"
            )
        end)

        it("gets and creates specific week", function()
            local result = test_state.journal:week_for("2024-W07", true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_true(path:exists(), "file was not created")
        end)

        it("creates specific week with matching template", function()
            test_state.copy_with_opts {
                weekly_template_name = "weekly",
            }

            ---@type obs.utils.Path
            local weekly_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "weekly.md"

            local expected_text = "this is example template 2024-W07"
            weekly_file_template:write(expected_text, "w")

            local result = test_state.journal:week_for("2024-W07", true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())
            local resulting_text = path:read()

            assert.are.equal(expected_text, resulting_text)
        end)

        describe("list", function()
            local state = journal_fixture()

            it("no entries", function()
                local result = state.journal:list_weeklies()

                assert.are.equal(0, #result, "wrong number of dailies")
            end)

            it("correct entries", function()
                local first_note = state.journal_dir_path.path / "2022-W04.md"
                first_note:touch {}
                local second_note = state.journal_dir_path.path / "2022-W06.md"
                second_note:touch {}

                local result = state.journal:list_weeklies()

                assert.are.equal(2, #result, "wrong number of dailies")
            end)

            it("lists sorted weekly dates", function()
                local first_note = state.journal_dir_path.path / "2024-W05.md"
                local second_note = state.journal_dir_path.path / "2023-W52.md"
                local third_note = state.journal_dir_path.path / "2024-W01.md"
                first_note:touch {}
                second_note:touch {}
                third_note:touch {}

                local result = state.journal:list_weekly_dates()

                assert.same({
                    "2023-W52",
                    "2024-W01",
                    "2024-W05",
                }, result)
            end)

            it("excludes non-weekly files when listing weekly dates", function()
                local weekly_note = state.journal_dir_path.path / "2024-W07.md"
                local daily_note = state.journal_dir_path.path / "2024-02-14.md"
                local normal_note = state.journal_dir_path.path / "note.md"
                weekly_note:touch {}
                daily_note:touch {}
                normal_note:touch {}

                local result = state.journal:list_weekly_dates()

                assert.same({ "2024-W07" }, result)
            end)
        end)
    end)

    describe("today", function()
        it("uses time provider by default", function()
            test_state.copy_with_opts {
                time_provider = function()
                    return time_for(2024, 2, 14)
                end,
            }

            local result = test_state.journal:today()

            assert.are.equal("2024-02-14", result:name(), "file name is wrong")
        end)

        it("uses custom date provider as a filename", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "custom-day"
                end,
            }

            local result = test_state.journal:today()

            assert.are.equal("custom-day", result:name(), "file name is wrong")
        end)

        it("get", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
            }

            local result = test_state.journal:today()

            assert.are.equal("2022-12-12", result:name(), "file name is wrong")
            assert.is_true(
                core.string_has_suffix(result:path(), ".md"),
                "file type is wrong"
            )
        end)

        it("get and not create file", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
            }

            local result = test_state.journal:today()

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_false(path:exists(), "file was created")
        end)

        it("get and create file", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
            }

            local result = test_state.journal:today(true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_true(path:exists(), "file was not created")
        end)

        it("creates missing nested journal directory", function()
            local journal_home = test_state.journal_dir_path.path
                / "missing"
                / "diary"
            test_state.journal = Journal:new(test_state.templater, {
                home = journal_home:expand(),
                date_provider = function()
                    return "2024-02-14"
                end,
            })

            assert.is_false(
                journal_home:exists(),
                "journal directory already exists"
            )

            local result = test_state.journal:today(true)
            local expected_path = journal_home / "2024-02-14.md"

            assert.is_true(
                journal_home:exists(),
                "journal directory was not created"
            )
            assert.is_true(expected_path:exists(), "daily note was not created")
            assert.are.equal(expected_path:expand(), result:path())
        end)

        it("create matching template", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
                daily_template_name = "daily",
            }

            ---@type obs.utils.Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "daily.md"

            local expected_text = "this is example template 2022-12-12"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:today(true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())
            local resulting_text = path:read()

            assert.are.equal(
                resulting_text,
                expected_text,
                string.format(
                    "Expected mathing template '%s' but was '%s'",
                    expected_text,
                    resulting_text
                )
            )
        end)

        it("create matching template using deprecated property", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
                template_name = "daily",
            }

            ---@type obs.utils.Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "daily.md"

            local expected_text = "this is example template 2022-12-12"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:today(true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())
            local resulting_text = path:read()

            assert.are.equal(
                resulting_text,
                expected_text,
                string.format(
                    "Expected mathing template '%s' but was '%s'",
                    expected_text,
                    resulting_text
                )
            )
        end)
    end)

    describe("daily for date", function()
        it("gets exact date note", function()
            local result = test_state.journal:daily_for "2024-02-14"

            assert.are.equal("2024-02-14", result:name(), "file name is wrong")
            assert.is_true(
                core.string_has_suffix(result:path(), ".md"),
                "file type is wrong"
            )
        end)

        it("get and create file", function()
            local result = test_state.journal:daily_for("2024-02-14", true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())

            assert.is_true(path:exists(), "file was not created")
        end)

        it("create matching template", function()
            test_state.copy_with_opts {
                daily_template_name = "daily",
            }

            ---@type obs.utils.Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "daily.md"

            local expected_text = "this is example template 2024-02-14"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:daily_for("2024-02-14", true)

            ---@type obs.utils.Path
            local path = Path:new(result:path())
            local resulting_text = path:read()

            assert.are.equal(
                resulting_text,
                expected_text,
                string.format(
                    "Expected mathing template '%s' but was '%s'",
                    expected_text,
                    resulting_text
                )
            )
        end)

        it("parses keywords", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2024-02-14"
                end,
                time_provider = function()
                    return time_for(2024, 2, 14)
                end,
            }

            assert.are.equal(
                "2024-02-14",
                test_state.journal:parse_daily_date "today"
            )
            assert.are.equal(
                "2024-02-15",
                test_state.journal:parse_daily_date "tomorrow"
            )
            assert.are.equal(
                "2024-02-13",
                test_state.journal:parse_daily_date "yesterday"
            )
        end)

        it("parses relative days", function()
            test_state.copy_with_opts {
                time_provider = function()
                    return time_for(2024, 2, 14)
                end,
            }

            assert.are.equal(
                "2024-02-13",
                test_state.journal:parse_daily_date "1 day ago"
            )
            assert.are.equal(
                "2024-02-12",
                test_state.journal:parse_daily_date "2 days ago"
            )
            assert.are.equal(
                "2024-02-15",
                test_state.journal:parse_daily_date "in 1 day"
            )
            assert.are.equal(
                "2024-02-16",
                test_state.journal:parse_daily_date "in 2 days"
            )
        end)

        it("rejects invalid exact date", function()
            local result = test_state.journal:daily_for("2024-02-30", true)
            local invalid_path = test_state.journal_dir_path.path
                / "2024-02-30.md"

            assert.is_nil(result)
            assert.is_false(invalid_path:exists(), "invalid file was created")
        end)

        it("rejects unsupported date text", function()
            local result = test_state.journal:daily_for("last friday", true)

            assert.is_nil(result)
        end)
    end)

    describe("list", function()
        local state = journal_fixture()

        it("no entries", function()
            local result = state.journal:list_dailies()

            assert.are.equal(0, #result, "wrong number of dailies")
        end)

        it("correct entries", function()
            local first_note = state.journal_dir_path.path / "2022-12-11.md"
            first_note:touch {}
            local second_note = state.journal_dir_path.path / "2022-12-12.md"
            second_note:touch {}

            local result = state.journal:list_dailies()

            assert.are.equal(2, #result, "wrong number of dailies")
        end)
    end)

    describe("complete daily dates", function()
        local state = journal_fixture()

        it("lists sorted daily dates", function()
            local first_note = state.journal_dir_path.path / "2024-02-14.md"
            local second_note = state.journal_dir_path.path / "2023-12-31.md"
            local third_note = state.journal_dir_path.path / "2024-01-01.md"
            first_note:touch {}
            second_note:touch {}
            third_note:touch {}

            local result = state.journal:list_daily_dates()

            assert.same({
                "2023-12-31",
                "2024-01-01",
                "2024-02-14",
            }, result)
        end)

        it("excludes non-daily files when listing daily dates", function()
            local daily_note = state.journal_dir_path.path / "2024-02-14.md"
            local weekly_note = state.journal_dir_path.path / "2024-W07.md"
            local normal_note = state.journal_dir_path.path / "note.md"
            daily_note:touch {}
            weekly_note:touch {}
            normal_note:touch {}

            local result = state.journal:list_daily_dates()

            assert.same({ "2024-02-14" }, result)
        end)

        it("no entries", function()
            local result = state.journal:complete_daily_dates ""

            assert.same({}, result)
        end)

        it("returns sorted existing daily dates", function()
            local first_note = state.journal_dir_path.path / "2024-02-14.md"
            local second_note = state.journal_dir_path.path / "2023-12-31.md"
            local third_note = state.journal_dir_path.path / "2024-01-01.md"
            first_note:touch {}
            second_note:touch {}
            third_note:touch {}

            local result = state.journal:complete_daily_dates ""

            assert.same({
                "2023-12-31",
                "2024-01-01",
                "2024-02-14",
            }, result)
        end)

        it("excludes non-daily files", function()
            local daily_note = state.journal_dir_path.path / "2024-02-14.md"
            local weekly_note = state.journal_dir_path.path / "2024-W07.md"
            local normal_note = state.journal_dir_path.path / "note.md"
            daily_note:touch {}
            weekly_note:touch {}
            normal_note:touch {}

            local result = state.journal:complete_daily_dates ""

            assert.same({ "2024-02-14" }, result)
        end)

        it("filters using prefix", function()
            local first_note = state.journal_dir_path.path / "2024-02-14.md"
            local second_note = state.journal_dir_path.path / "2024-02-15.md"
            local third_note = state.journal_dir_path.path / "2024-03-01.md"
            first_note:touch {}
            second_note:touch {}
            third_note:touch {}

            local result = state.journal:complete_daily_dates "2024-02"

            assert.same({ "2024-02-14", "2024-02-15" }, result)
        end)
    end)
end)
