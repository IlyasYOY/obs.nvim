local Path = require "plenary.path"
local Journal =    require "obs.journal"
local Templater = require "obs.templater"

local spec_utils = require "coredor.spec"
local core = require "coredor"

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

            ---@type Path
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

            ---@type Path
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

            ---@type Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "weekly.md"

            local expected_text = "this is example template 2022-W07"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:this_week(true)

            ---@type Path
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
        end)
    end)

    describe("today", function()
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

            ---@type Path
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

            ---@type Path
            local path = Path:new(result:path())

            assert.is_true(path:exists(), "file was not created")
        end)

        it("create matching template", function()
            test_state.copy_with_opts {
                date_provider = function()
                    return "2022-12-12"
                end,
                daily_template_name = "daily",
            }

            ---@type Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "daily.md"

            local expected_text = "this is example template 2022-12-12"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:today(true)

            ---@type Path
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

            ---@type Path
            local daily_file_template = Path:new(
                test_state.templates_dir_path.path
            ) / "daily.md"

            local expected_text = "this is example template 2022-12-12"
            daily_file_template:write(expected_text, "w")

            local result = test_state.journal:today(true)

            ---@type Path
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
end)
