local Vault = require "obs.vault"
local spec = require "obs.utils.spec"
local File = require "obs.utils.file"
local utils = require "obs.utils"

local function vault_fixture()
    local result = {}

    local vault_home = spec.temp_dir_fixture()

    before_each(function()
        result.vault = Vault:new {
            vault_home = vault_home.path:expand(),
            time_provider = function()
                if result.time_mock then
                    return result.time_mock
                end
                local time = os.clock()
                return time
            end,
        }
        result.home = vault_home.path
    end)

    ---creates file in vault
    ---@param name string file name
    ---@return obs.utils.File
    function result.create_file(name)
        ---@type obs.utils.Path
        local file_path = (vault_home.path / name)
        file_path:touch()
        return File:new(file_path:expand())
    end

    return result
end

describe("new note", function()
    local state = vault_fixture()
    local common_time = 1675255557
    local common_name = "2023-02-01-" .. common_time
    local common_filename = common_name .. ".md"
    ---@type fun(): obs.utils.Path
    local common_filepath = function()
        return state.home / common_filename
    end

    it("for correct note", function()
        state.time_mock = common_time

        local file = state.vault:create_note "cool note"

        local expected_name = "2023-02-01-cool note"
        local expected_filename = expected_name .. ".md"

        assert(file)
        assert.file(
            file,
            expected_name,
            vim.fn.resolve((state.home / expected_filename):expand())
        )
    end)

    it("for existing note", function()
        state.time_mock = common_time
        common_filepath():touch()

        local file = state.vault:create_note ""

        assert(file == nil, "file should not be overriten")
    end)

    it("for nil name", function()
        state.time_mock = common_time

        local file = state.vault:create_note(nil)

        assert(file)
        assert.file(
            file,
            common_name,
            vim.fn.resolve(common_filepath():expand())
        )
    end)

    it("for '' name", function()
        state.time_mock = common_time

        local file = state.vault:create_note ""

        assert(file)
        assert.file(
            file,
            common_name,
            vim.fn.resolve(common_filepath():expand())
        )
    end)
end)

describe("daily note completion", function()
    local state = vault_fixture()

    it("parses daily date queries", function()
        local result = state.vault:parse_daily_date "2024-02-14"

        assert.are.equal("2024-02-14", result)
    end)

    it("lists existing daily dates", function()
        local first_note = state.home / "diary" / "2024-02-14.md"
        local second_note = state.home / "diary" / "2024-02-15.md"
        first_note:touch {}
        second_note:touch {}

        local result = state.vault:list_daily_dates()

        assert.same({ "2024-02-14", "2024-02-15" }, result)
    end)

    it("completes existing daily dates", function()
        local first_note = state.home / "diary" / "2024-02-14.md"
        local second_note = state.home / "diary" / "2024-02-15.md"
        local third_note = state.home / "diary" / "2024-03-01.md"
        first_note:touch {}
        second_note:touch {}
        third_note:touch {}

        local result = state.vault:complete_daily_dates "2024-02"

        assert.same({ "2024-02-14", "2024-02-15" }, result)
    end)
end)

describe("weekly note", function()
    local state = vault_fixture()

    it("opens specific weekly note through journal", function()
        local received_week
        state.vault._journal = {
            open_weekly_for = function(_, week)
                received_week = week
            end,
        }

        state.vault:open_weekly_for "2024-W07"

        assert.are.equal("2024-W07", received_week)
    end)

    it("lists existing weekly dates", function()
        local first_note = state.home / "diary" / "2024-W05.md"
        local second_note = state.home / "diary" / "2024-W01.md"
        first_note:touch {}
        second_note:touch {}

        local result = state.vault:list_weekly_dates()

        assert.same({ "2024-W01", "2024-W05" }, result)
    end)
end)

describe("find backlinks", function()
    local state = vault_fixture()

    it("no note", function()
        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note1"

        assert.list_size(backlinks, 0)
    end)

    it("no backlinks", function()
        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 0)
    end)

    it("one backlink", function()
        ---@type obs.utils.Path
        local note1 = (state.home / "note1.md")
        note1:touch()
        note1:write("This is file with a link to [[note]].", "w")

        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 1)
        assert.file(backlinks[1], "note1", vim.fn.resolve(note1:expand()))
    end)

    it("multiple backlink", function()
        ---@type obs.utils.Path
        local note1 = (state.home / "note1.md")
        note1:touch()
        note1:write("This is file with a link to [[note]].", "w")

        ---@type obs.utils.Path
        local note2 = (state.home / "note2.md")
        note2:touch()
        note2:write("This is the second file with a link to [[note]].", "w")

        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 2)
    end)

    it("multiple links per file backlink", function()
        ---@type obs.utils.Path
        local note1 = (state.home / "note1.md")
        note1:touch()
        note1:write(
            "This is file with a link to [[note]] and one more [[note]].",
            "w"
        )

        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 1)
    end)
end)

describe("list", function()
    local state = vault_fixture()

    it("no items", function()
        local notes = state.vault:list_notes()

        assert.list_size(notes, 0)
    end)

    it("list item", function()
        local file = (state.home / "note1.md")
        file:touch()

        local notes = state.vault:list_notes()

        local note = notes[#notes]

        assert.file(note, "note1", vim.fn.resolve(file:expand()))
    end)

    it("md items", function()
        local file0 = (state.home / "note1.md")
        local file1 = (state.home / "note2.md")
        file0:touch()
        file1:touch()

        local notes = state.vault:list_notes()

        assert.list_size(notes, 2)
    end)

    it("nested md items", function()
        local nested_dir = state.home / "dir"
        nested_dir:mkdir()

        local file0 = (nested_dir / "note1.md")
        local file1 = (nested_dir / "note2.md")

        file0:touch()
        file1:touch()

        local notes = state.vault:list_notes()

        assert.list_size(notes, 2)
    end)

    it("not md items", function()
        local file0 = (state.home / "note1.txt")
        local file1 = (state.home / "note2.txt")
        file0:touch()
        file1:touch()

        local notes = state.vault:list_notes()

        assert.list_size(notes, 0)
    end)
end)

describe("copy current note link", function()
    local state = vault_fixture()
    local original_save_to_exchange_buffer

    local function edit_note(note)
        vim.cmd("edit " .. vim.fn.fnameescape(note:path()))
        vim.bo.filetype = "markdown"
    end

    before_each(function()
        original_save_to_exchange_buffer = utils.save_to_exchange_buffer
    end)

    after_each(function()
        utils.save_to_exchange_buffer = original_save_to_exchange_buffer
        vim.cmd "enew!"
    end)

    it("returns wiki link for current note", function()
        local note = state.create_file "my note.md"
        edit_note(note)

        local link = state.vault:get_wiki_link_to_current_note()

        assert.are.equal("[[my note]]", link)
    end)

    it("copies wiki link for current note", function()
        local note = state.create_file "my note.md"
        local saved_link
        utils.save_to_exchange_buffer = function(link)
            saved_link = link
        end
        edit_note(note)

        state.vault:copy_wiki_link_to_current_note()

        assert.are.equal("[[my note]]", saved_link)
    end)

    it("does not return wiki link outside note buffers", function()
        local note = state.create_file "my note.md"
        edit_note(note)
        vim.bo.filetype = "text"

        local link = state.vault:get_wiki_link_to_current_note()

        assert.is_nil(link)
    end)
end)

describe("rename", function()
    local state = vault_fixture()

    it("file not exist", function()
        local renamed_note = state.vault:rename("test", "new test")
        assert.is_nil(renamed_note, "no note to rename should be found")
    end)

    it("file renamed", function()
        state.create_file "test.md"

        local renamed = state.vault:rename("test", "new test")

        assert(renamed, "file should be found")
        assert.file(
            renamed,
            "new test",
            vim.fn.resolve((state.home / "new test.md"):expand())
        )
    end)

    it("simple link renamed", function()
        state.create_file "test.md"
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path:write("This s a link to test.md [[test]].", "w")

        state.vault:rename("test", "new test")

        assert.is.equal(
            "This s a link to test.md [[new test]].",
            note_with_link_path:read(),
            "index should not be null"
        )
    end)

    it("regex-like (with magic characters) link renamed", function()
        state.create_file "2022-01-01 something.md"
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path:write(
            "This s a link to test.md [[2022-01-01 something]].",
            "w"
        )

        state.vault:rename("2022-01-01 something", "new test")

        assert.is.equal(
            "This s a link to test.md [[new test]].",
            note_with_link_path:read(),
            "index should not be null"
        )
    end)

    it("alias link renamed", function()
        state.create_file "test.md"
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path:write(
            "This s a link to test.md [[test|alias]].",
            "w"
        )

        state.vault:rename("test", "new test")

        assert.is.equal(
            "This s a link to test.md [[new test|alias]].",
            note_with_link_path:read(),
            "index should not be null"
        )
    end)

    it("header link renamed", function()
        state.create_file "test.md"
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path:write(
            "This s a link to test.md [[test#header]].",
            "w"
        )

        state.vault:rename("test", "new test")

        assert.is.equal(
            "This s a link to test.md [[new test#header]].",
            note_with_link_path:read(),
            "index should not be null"
        )
    end)
end)
