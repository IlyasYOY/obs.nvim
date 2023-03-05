local Vault = require "obs.vault"
local spec = require "coredor.spec"
local File = require "coredor.file"

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
    ---@return coredor.File
    function result.create_file(name)
        ---@type Path
        local file_path = (vault_home.path / name)
        file_path:touch()
        return File:new(file_path:expand())
    end

    return result
end

describe("new note", function()
    local state = vault_fixture()
    local common_time = 1675255557
    local common_name = "2023-02-01 " .. common_time
    local common_filename = common_name .. ".md"
    ---@type fun(): Path
    local common_filepath = function()
        return state.home / common_filename
    end

    it("for correct note", function()
        state.time_mock = common_time

        local file = state.vault:create_note "cool note"

        local expected_name = "2023-02-01 cool note"
        local expected_filename = expected_name .. ".md"

        assert(file)
        assert.file(
            file,
            expected_name,
            (state.home / expected_filename):expand()
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
        assert.file(file, common_name, common_filepath():expand())
    end)

    it("for '' name", function()
        state.time_mock = common_time

        local file = state.vault:create_note ""

        assert(file)
        assert.file(file, common_name, common_filepath():expand())
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
        ---@type Path
        local note1 = (state.home / "note1.md")
        note1:touch()
        note1:write("This is file with a link to [[note]].", "w")

        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 1)
        assert.file(backlinks[1], "note1", note1:expand())
    end)

    it("multiple backlink", function()
        ---@type Path
        local note1 = (state.home / "note1.md")
        note1:touch()
        note1:write("This is file with a link to [[note]].", "w")

        ---@type Path
        local note2 = (state.home / "note2.md")
        note2:touch()
        note2:write("This is the second file with a link to [[note]].", "w")

        local note = (state.home / "note.md")
        note:touch()

        local backlinks = state.vault:list_backlinks "note"

        assert.list_size(backlinks, 2)
    end)

    it("multiple links per file backlink", function()
        ---@type Path
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

        assert.file(note, "note1", file:expand())
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
        assert.file(renamed, "new test", (state.home / "new test.md"):expand())
    end)

    it("simple link renamed", function()
        state.create_file "test.md"
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path
            :as_plenary()
            :write("This s a link to test.md [[test]].", "w")

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
        note_with_link_path
            :as_plenary()
            :write("This s a link to test.md [[2022-01-01 something]].", "w")

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
        note_with_link_path
            :as_plenary()
            :write("This s a link to test.md [[test|alias]].", "w")

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
        note_with_link_path
            :as_plenary()
            :write("This s a link to test.md [[test#header]].", "w")

        state.vault:rename("test", "new test")

        assert.is.equal(
            "This s a link to test.md [[new test#header]].",
            note_with_link_path:read(),
            "index should not be null"
        )
    end)
end)
