local Vault = require "obs.vault"
local spec = require "obs.utils.spec"
local File = require "obs.utils.file"
local Path = require "obs.utils.path"
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

    local function configure_note_template(template_text)
        local templates_home = state.home / "meta" / "templates"
        local template_path = templates_home / "note.md"
        template_path:write(template_text, "w")

        state.vault = Vault:new {
            vault_home = state.home:expand(),
            time_provider = function()
                return state.time_mock or common_time
            end,
            templater = {
                note_template_name = "note",
                extra_providers = {
                    {
                        name = "filename",
                        func = function(context)
                            return context.filename
                        end,
                    },
                },
            },
        }
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

    it("creates empty file when note template is not configured", function()
        state.time_mock = common_time

        local file = state.vault:create_note "cool note"

        assert.are.equal("", file:read())
    end)

    it("creates note with matching template", function()
        state.time_mock = common_time
        configure_note_template "Title: {{title}}\nFilename: {{filename}}"

        local file = state.vault:create_note "cool note"

        assert.are.equal(
            "Title: 2023-02-01-cool note\nFilename: 2023-02-01-cool note.md",
            file:read()
        )
    end)

    it("creates unnamed note with matching template", function()
        state.time_mock = common_time
        configure_note_template "Title: {{title}}\nFilename: {{filename}}"

        local file = state.vault:create_note ""

        assert.are.equal(
            "Title: 2023-02-01-1675255557\nFilename: 2023-02-01-1675255557.md",
            file:read()
        )
    end)

    it("does not overwrite existing note with configured template", function()
        state.time_mock = common_time
        local existing_note = state.home / "2023-02-01-cool note.md"
        existing_note:write("existing content", "w")
        configure_note_template "new content"

        local file = state.vault:create_note "cool note"

        assert.is_nil(file)
        assert.are.equal("existing content", existing_note:read())
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

describe("tags", function()
    local state = vault_fixture()
    local original_select = vim.ui.select
    local original_notify = vim.notify

    local function create_note(name, content)
        local note = state.create_file(name)
        note:write(content, "w")
        return note
    end

    local function edit_note(note)
        note:edit()
        vim.bo.filetype = "markdown"
    end

    after_each(function()
        vim.ui.select = original_select
        vim.notify = original_notify
        vim.cmd "enew!"
    end)

    it("lists sorted unique tags across notes", function()
        create_note(
            "first.md",
            table.concat({
                "---",
                "tags: [zeta, #alpha]",
                "---",
                "#work",
            }, "\n")
        )
        create_note("second.md", "#work #beta")

        local tags = state.vault:list_tags()

        assert.same({ "alpha", "beta", "work", "zeta" }, tags)
    end)

    it("lists and completes UTF-8 tags without numeric or code tags", function()
        local note = create_note(
            "unicode.md",
            "Issue #123 uses `#inline` before #работа"
        )
        create_note("noise.md", "#123 `#inline`")

        local tags = state.vault:list_tags()
        local notes = state.vault:list_notes_with_tag "работа"

        assert.same({ "работа" }, tags)
        assert.same({ "#работа" }, state.vault:complete_tags "#р")
        assert.same({}, state.vault:complete_tags "#1")
        assert.list_size(notes, 1)
        assert.file(notes[1], "unicode", note:path())
    end)

    it("lists notes with exact tag matches", function()
        local first = create_note("first.md", "#work")
        create_note("second.md", "#workflow")
        local third = create_note("third.md", "#work #other")

        local notes = state.vault:list_notes_with_tag "work"

        assert.list_size(notes, 2)
        assert.file(notes[1], "first", first:path())
        assert.file(notes[2], "third", third:path())
    end)

    it("returns no notes for unknown tag", function()
        create_note("first.md", "#work")

        local notes = state.vault:list_notes_with_tag "missing"

        assert.same({}, notes)
    end)

    it("notifies when no tags exist", function()
        local notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        state.vault:find_tags()

        assert.same({ "No tags found" }, notifications)
    end)

    it("selects a tag and opens a selected matching note", function()
        create_note("first.md", "#home")
        local work_note = create_note("second.md", "#work")
        create_note("third.md", "#work")
        local calls = {}

        vim.ui.select = function(items, opts, callback)
            calls[#calls + 1] = {
                items = items,
                prompt = opts.prompt,
                first_label = opts.format_item(items[1]),
            }

            if #calls == 1 then
                callback "work"
                return
            end

            for _, note in ipairs(items) do
                if note:path() == work_note:path() then
                    callback(note)
                    return
                end
            end
        end

        state.vault:find_tags()

        assert.are.equal("Tags", calls[1].prompt)
        assert.same({ "home", "work" }, calls[1].items)
        assert.are.equal("#home", calls[1].first_label)
        assert.are.equal("Notes tagged #work", calls[2].prompt)
        assert.are.equal("second", calls[2].first_label)
        assert.are.equal(work_note:path(), vim.api.nvim_buf_get_name(0))
    end)

    it("finds notes for a normalized tag argument", function()
        local note = create_note("work.md", "#work")
        local calls = {}

        vim.ui.select = function(items, opts, callback)
            calls[#calls + 1] = {
                items = items,
                prompt = opts.prompt,
                first_label = opts.format_item(items[1]),
            }
            callback(items[1])
        end

        state.vault:find_tag "#work"

        assert.are.equal("Notes tagged #work", calls[1].prompt)
        assert.are.equal("work", calls[1].first_label)
        assert.are.equal(note:path(), vim.api.nvim_buf_get_name(0))
    end)

    it("notifies when no tag argument is provided", function()
        local notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        state.vault:find_tag "#"

        assert.same({ "No tag was provided" }, notifications)
    end)

    it("notifies when a tag argument has no matching notes", function()
        local notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        state.vault:find_tag "missing"

        assert.same({ "No notes found for tag #missing" }, notifications)
    end)

    it("finds notes for tag under cursor", function()
        local note = create_note("current.md", "before #work after")
        create_note("other.md", "#work")
        local calls = {}
        edit_note(note)
        local tag_start = string.find("before #work after", "#work", 1, true)
        vim.api.nvim_win_set_cursor(0, { 1, tag_start + 1 })

        vim.ui.select = function(items, opts, callback)
            calls[#calls + 1] = {
                items = items,
                prompt = opts.prompt,
            }
            callback(items[1])
        end

        state.vault:find_tag_under_cursor()

        assert.are.equal("Notes tagged #work", calls[1].prompt)
        assert.list_size(calls[1].items, 2)
    end)

    it("notifies when no tag is under cursor", function()
        local note = create_note("current.md", "no tag here")
        local notifications = {}
        edit_note(note)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        state.vault:find_tag_under_cursor()

        assert.same({ "No tag was found under the cursor" }, notifications)
    end)

    it(
        "notifies when selected tag has no matching notes after rescan",
        function()
            local note = create_note("first.md", "#stale")
            local notifications = {}

            vim.notify = function(message)
                notifications[#notifications + 1] = message
            end
            vim.ui.select = function(_, _, callback)
                note:write("No tags now", "w")
                callback "stale"
            end

            state.vault:find_tags()

            assert.same({ "No notes found for tag #stale" }, notifications)
        end
    )
end)

describe("next link", function()
    local state = vault_fixture()
    local original_notify = vim.notify

    local function edit_current_note(lines)
        local note = state.create_file "current.md"
        note:write(table.concat(lines, "\n"), "w")
        note:edit()
        vim.bo.filetype = "markdown"
    end

    local function wiki_col(line, name)
        local start_col = string.find(line, "[[" .. name, 1, true)
        assert.is_not_nil(start_col)
        return start_col + 1
    end

    local function markdown_col(line, label)
        local start_col = string.find(line, "[" .. label, 1, true)
        assert.is_not_nil(start_col)
        return start_col
    end

    local function url_col(line, url)
        local start_col = string.find(line, url, 1, true)
        assert.is_not_nil(start_col)
        return start_col - 1
    end

    local function assert_cursor(line, col)
        local cursor = vim.api.nvim_win_get_cursor(0)

        assert.are.equal(line, cursor[1], "wrong cursor line")
        assert.are.equal(col, cursor[2], "wrong cursor column")
    end

    after_each(function()
        vim.notify = original_notify
        local bufnr = vim.api.nvim_get_current_buf()
        vim.cmd "enew!"
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    it("moves forward through wiki links", function()
        local lines = {
            "[markdown](note.md) before [[one]]",
            "then [[two]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, false)
        assert_cursor(1, wiki_col(lines[1], "one"))

        state.vault:next_link(1, false)
        assert_cursor(2, wiki_col(lines[2], "two"))
    end)

    it("includes Markdown links when requested", function()
        local lines = {
            "[markdown](note.md) before [[one]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, true)

        assert_cursor(1, markdown_col(lines[1], "markdown"))
    end)

    it("includes bare HTTP links when requested", function()
        local lines = {
            "see https://example.com before [[one]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, true)

        assert_cursor(1, url_col(lines[1], "https://example.com"))
    end)

    it("includes a first-column bare HTTP link before later links", function()
        local lines = {
            "https://vk.com/ [[later]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, true)

        assert_cursor(1, url_col(lines[1], "https://vk.com/"))
    end)

    it("reaches a second same-line link after a first-column URL", function()
        local lines = {
            "https://vk.com/ [[later]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, true)
        state.vault:next_link(1, true)

        assert_cursor(1, wiki_col(lines[1], "later"))
    end)

    it("counts through a first-column URL to a later same-line link", function()
        local lines = {
            "https://vk.com/ [[later]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(2, true)

        assert_cursor(1, wiki_col(lines[1], "later"))
    end)

    it("lands inside labels of Markdown image syntax links", function()
        local lines = {
            "see ![link](https://vk.com/) before [[one]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, true)

        assert_cursor(1, markdown_col(lines[1], "link"))
    end)

    it("moves backward and wraps around", function()
        local lines = {
            "[[one]]",
            "[[two]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, wiki_col(lines[1], "one") })

        state.vault:next_link(-1, false)

        assert_cursor(2, wiki_col(lines[2], "two"))
    end)

    it("supports counts", function()
        local lines = {
            "[[one]] [[two]] [[three]]",
        }
        edit_current_note(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(2, false)

        assert_cursor(1, wiki_col(lines[1], "two"))
    end)

    it("notifies when no matching links exist", function()
        local notifications = {}
        vim.notify = function(message, level)
            notifications[#notifications + 1] = {
                level = level,
                message = message,
            }
        end
        edit_current_note { "[markdown](note.md) https://example.com" }
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        state.vault:next_link(1, false)

        assert.same({
            {
                level = nil,
                message = "No links found",
            },
        }, notifications)
        assert_cursor(1, 0)
    end)
end)

describe("copy current note link", function()
    local state = vault_fixture()
    local original_save_to_exchange_buffer
    local sibling_home_to_remove

    local function edit_note(note)
        vim.cmd("edit " .. vim.fn.fnameescape(note:path()))
        vim.bo.filetype = "markdown"
    end

    before_each(function()
        original_save_to_exchange_buffer = utils.save_to_exchange_buffer
    end)

    after_each(function()
        utils.save_to_exchange_buffer = original_save_to_exchange_buffer
        if sibling_home_to_remove then
            sibling_home_to_remove:rm()
            sibling_home_to_remove = nil
        end
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

    it("does not return wiki link for sibling vault path", function()
        local sibling_home = Path:new(state.home:expand() .. "-old")
        sibling_home_to_remove = sibling_home
        local sibling_note_path = sibling_home / "my note.md"
        sibling_note_path:touch()
        local sibling_note = File:new(sibling_note_path:expand())
        edit_note(sibling_note)

        local link = state.vault:get_wiki_link_to_current_note()

        assert.is_nil(link)
    end)
end)

describe("move current note", function()
    local state = vault_fixture()
    local original_select
    local original_notify
    local notifications
    local source
    local source_buf
    local destination

    before_each(function()
        vim.cmd "silent! %bwipeout!"
        original_select = vim.ui.select
        original_notify = vim.notify
        notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end
        source = state.create_file "a/note.md"
        source:write "source content"
        source:edit()
        source_buf = vim.api.nvim_get_current_buf()
        local folder = state.home / "b"
        folder:mkdir()
        destination = File:new(folder / "note.md")
        vim.ui.select = function(_, _, callback)
            callback(folder:expand())
        end
    end)

    after_each(function()
        vim.ui.select = original_select
        vim.notify = original_notify
        vim.cmd "silent! %bwipeout!"
    end)

    local function assert_source_preserved()
        assert.are.equal("source content", source:read())
        assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
        assert.is_true(vim.api.nvim_buf_is_loaded(source_buf))
        assert.are.equal(source:path(), vim.api.nvim_buf_get_name(source_buf))
    end

    it(
        "rejects an existing destination without changing either note",
        function()
            destination:write "destination content"

            state.vault:find_directory_and_move_current_note()

            assert_source_preserved()
            assert.are.equal("destination content", destination:read())
            assert.same(
                { "source content" },
                vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
            )
            assert.same({
                "Destination already exists: " .. destination:path(),
            }, notifications)
        end
    )

    it("preserves unsaved changes when the destination exists", function()
        destination:write "destination content"
        vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
            "unsaved content",
        })

        state.vault:find_directory_and_move_current_note()

        assert_source_preserved()
        assert.are.equal("destination content", destination:read())
        assert.same(
            { "unsaved content" },
            vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
        )
        assert.is_true(vim.bo[source_buf].modified)
    end)

    it("moves to an unused destination", function()
        state.vault:find_directory_and_move_current_note()

        assert.is_false(source:exists())
        assert.are.equal("source content", destination:read())
        assert.are.equal(destination:path(), vim.api.nvim_buf_get_name(0))
        assert.same({}, notifications)
    end)

    it("rejects moving into the current folder", function()
        vim.ui.select = function(_, _, callback)
            callback((state.home / "a"):expand())
        end

        state.vault:find_directory_and_move_current_note()

        assert_source_preserved()
        assert.same({
            "Destination already exists: " .. source:path(),
        }, notifications)
    end)

    it("preserves the source when selection is cancelled", function()
        vim.ui.select = function(_, _, callback)
            callback(nil)
        end

        state.vault:find_directory_and_move_current_note()

        assert_source_preserved()
        assert.is_false(destination:exists())
        assert.same({}, notifications)
    end)
end)

describe("rename current note", function()
    local state = vault_fixture()
    local original_input
    local original_notify
    local original_hidden
    local notifications
    local source
    local source_buf
    local destination

    before_each(function()
        vim.cmd "silent! %bwipeout!"
        original_input = vim.fn.input
        original_notify = vim.notify
        original_hidden = vim.o.hidden
        notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end
        vim.fn.input = function()
            return "new test"
        end
        source = state.create_file "test.md"
        source:write "saved text\n"
        source:edit()
        vim.bo.filetype = "markdown"
        source_buf = vim.api.nvim_get_current_buf()
        destination = File:new(state.home / "new test.md")
    end)

    after_each(function()
        vim.fn.input = original_input
        vim.notify = original_notify
        vim.o.hidden = original_hidden
        vim.cmd "silent! %bwipeout!"
    end)

    local function assert_renamed_buffer()
        assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
        assert.are.equal(
            destination:path(),
            vim.api.nvim_buf_get_name(source_buf)
        )
        assert.is_false(source:exists())
        assert.is_true(destination:exists())
    end

    for _, hidden in ipairs { true, false } do
        it(
            "preserves edits through write with hidden=" .. tostring(hidden),
            function()
                vim.o.hidden = hidden
                local lines = { "saved text", "unsaved edit" }
                vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, lines)

                state.vault:rename_current_note()

                assert_renamed_buffer()
                assert.same(
                    lines,
                    vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
                )
                assert.is_true(vim.bo[source_buf].modified)
                assert.are.equal("saved text\n", destination:read())
                vim.cmd "write"
                assert.are.equal(
                    "saved text\nunsaved edit\n",
                    destination:read()
                )
                assert.is_false(source:exists())
            end
        )
    end

    it("keeps the original unmodified buffer", function()
        state.vault:rename_current_note()

        assert_renamed_buffer()
        assert.same(
            { "saved text" },
            vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
        )
        assert.is_false(vim.bo[source_buf].modified)
    end)

    it("keeps saved self links unmodified after rename", function()
        source:write "[[test]]\n"
        vim.cmd "edit!"

        state.vault:rename_current_note()

        assert_renamed_buffer()
        assert.same(
            { "[[new test]]" },
            vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
        )
        assert.are.equal("[[new test]]\n", destination:read())
        assert.is_false(vim.bo[source_buf].modified)
    end)

    it("updates saved and unsaved self links through write", function()
        source:write "[[test]]\n"
        vim.cmd "edit!"
        vim.api.nvim_buf_set_lines(source_buf, 1, -1, false, {
            "unsaved [[test|alias]] and [[test#header]]",
        })

        state.vault:rename_current_note()

        assert_renamed_buffer()
        assert.same({
            "[[new test]]",
            "unsaved [[new test|alias]] and [[new test#header]]",
        }, vim.api.nvim_buf_get_lines(source_buf, 0, -1, false))
        assert.is_true(vim.bo[source_buf].modified)
        assert.are.equal("[[new test]]\n", destination:read())
        vim.cmd "write"
        assert.are.equal(
            "[[new test]]\nunsaved [[new test|alias]] and [[new test#header]]\n",
            destination:read()
        )
        assert.is_false(source:exists())
    end)

    it("allows a destination that partially matches another buffer", function()
        vim.fn.bufadd(destination:path() .. ".bak")

        state.vault:rename_current_note()

        assert_renamed_buffer()
    end)

    for _, conflict in ipairs { "file", "buffer", "buffer with brackets" } do
        it(
            "rejects a destination " .. conflict .. " before mutation",
            function()
                local other_buf
                if conflict == "file" then
                    destination:write "destination content"
                else
                    if conflict == "buffer with brackets" then
                        destination = File:new(state.home / "new [test].md")
                        vim.fn.input = function()
                            return "new [test]"
                        end
                    end
                    other_buf = vim.fn.bufadd(destination:path())
                    vim.fn.bufload(other_buf)
                    vim.api.nvim_buf_set_lines(
                        other_buf,
                        0,
                        -1,
                        false,
                        { "other edits" }
                    )
                end
                local backlink = state.create_file "backlink.md"
                backlink:write "[[test]]"
                vim.api.nvim_buf_set_lines(
                    source_buf,
                    0,
                    -1,
                    false,
                    { "unsaved edit" }
                )

                state.vault:rename_current_note()

                assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
                assert.are.equal(
                    source:path(),
                    vim.api.nvim_buf_get_name(source_buf)
                )
                assert.same(
                    { "unsaved edit" },
                    vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
                )
                assert.is_true(vim.bo[source_buf].modified)
                assert.are.equal("saved text\n", source:read())
                assert.are.equal("[[test]]", backlink:read())
                assert.are.equal(1, #notifications)
                if other_buf then
                    assert.is_false(destination:exists())
                    assert.same(
                        { "other edits" },
                        vim.api.nvim_buf_get_lines(other_buf, 0, -1, false)
                    )
                    assert.is_true(vim.bo[other_buf].modified)
                else
                    assert.are.equal("destination content", destination:read())
                end
            end
        )
    end
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

    it("does not overwrite existing note", function()
        local old_note = state.create_file "test.md"
        local existing_note = state.create_file "new test.md"
        old_note:write("old content", "w")
        existing_note:write("existing content", "w")
        local note_with_link_path = state.create_file "note-with-link.md"
        note_with_link_path:write("[[test]]", "w")

        local renamed = state.vault:rename("test", "new test")

        assert.is_nil(renamed)
        assert.are.equal("old content", old_note:read())
        assert.are.equal("existing content", existing_note:read())
        assert.are.equal("[[test]]", note_with_link_path:read())
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

    it("preserves percent signs in renamed links", function()
        state.create_file "test.md"
        local simple_link_path = state.create_file "simple-link.md"
        local alias_link_path = state.create_file "alias-link.md"
        local header_link_path = state.create_file "header-link.md"
        simple_link_path:write("[[test]]", "w")
        alias_link_path:write("[[test|alias]]", "w")
        header_link_path:write("[[test#header]]", "w")

        state.vault:rename("test", "100% done")

        assert.are.equal("[[100% done]]", simple_link_path:read())
        assert.are.equal("[[100% done|alias]]", alias_link_path:read())
        assert.are.equal("[[100% done#header]]", header_link_path:read())
    end)
end)

describe("open random note", function()
    local state = vault_fixture()
    local original_notify

    before_each(function()
        original_notify = vim.notify
    end)

    after_each(function()
        vim.notify = original_notify
    end)

    it("notifies when vault is empty", function()
        local notifications = {}
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end

        state.vault:open_random_note()

        assert.same({ "No notes found" }, notifications)
    end)
end)

describe("open note", function()
    local state = vault_fixture()

    after_each(function()
        vim.cmd "enew!"
    end)

    it("opens paths with Ex metacharacters", function()
        local note = state.create_file "note|suffix.md"

        state.vault:open_note "note|suffix"

        assert.are.equal(note:path(), vim.api.nvim_buf_get_name(0))
    end)
end)
