local Completion = require "obs.completion"
local File = require "obs.utils.file"
local Path = require "obs.utils.path"
local Vault = require "obs.vault"
local spec = require "obs.utils.spec"

local default_complete = ".,w,b,u,t"
local completion_supported = vim.fn.has "nvim-0.12" == 1

local function completion_fixture()
    local result = {}
    local vault_home = spec.temp_dir_fixture()

    ---creates file in vault
    ---@param name string file name
    ---@return obs.utils.File
    function result.create_file(name)
        local file_path = vault_home.path / name
        vim.fn.mkdir(file_path:parent():expand(), "p")
        file_path:touch()
        return File:new(file_path:expand())
    end

    before_each(function()
        Completion.disable()
        result.vault = Vault:new {
            vault_home = vault_home.path:expand(),
        }
        result.home = vault_home.path
        result.current_note = result.create_file "current.md"
        vim.cmd("edit " .. result.current_note:path())
        vim.bo.filetype = "markdown"
        vim.bo.complete = default_complete
        vim.bo.completefunc = ""
    end)

    after_each(function()
        Completion.disable()
        if result.sibling_home then
            result.sibling_home:rm()
            result.sibling_home = nil
        end
        local bufnr = vim.api.nvim_get_current_buf()
        vim.bo.complete = default_complete
        vim.bo.completefunc = ""
        vim.cmd "enew!"
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    return result
end

describe("completion context", function()
    local find_context = Completion._find_wiki_link_context

    local function assert_no_context(line, cursor_col)
        assert.is_nil(find_context(line, cursor_col), "context must be absent")
    end

    local function assert_context(
        line,
        cursor_col,
        start_col,
        base,
        append_closing_brackets
    )
        if append_closing_brackets == nil then
            append_closing_brackets = true
        end

        local context = find_context(line, cursor_col)
        assert.is_not_nil(context)
        assert.are.equal(start_col, context.start_col, "wrong start column")
        assert.are.equal(base, context.base, "wrong base")
        assert.are.equal(
            append_closing_brackets,
            context.append_closing_brackets,
            "wrong append closing brackets state"
        )
    end

    it("is absent outside wiki link", function()
        assert_no_context("hello note", #"hello note")
    end)

    it("is present after opening brackets", function()
        assert_context("[[", #"[[", 2, "")
    end)

    it("is present after partial note name", function()
        assert_context("[[foo", #"[[foo", 2, "foo")
    end)

    it("is present inside closed link before closing brackets", function()
        assert_context("[[foo]]", #"[[foo", 2, "foo", false)
    end)

    it("finds the name boundary beyond the cursor", function()
        for _, suffix in ipairs { "]]", "|alias]]", "#heading]]" } do
            assert_context("[[new" .. suffix, #"[[n", 2, "n", false)
        end
        assert_context("[[новая]]", #"[[но", 2, "но", false)
        assert_context("[[old]] [[new]]", #"[[old]] [[n", 10, "n", false)
    end)

    it("does not borrow a boundary from the next link", function()
        assert_context("[[n text [[other]]", #"[[n", 2, "n", true)
        assert_context("[[n text [[other|alias]]", #"[[n", 2, "n", true)
        assert_context("[[n text [[other#heading]]", #"[[n", 2, "n", true)
    end)

    it("recognizes an unfinished alias or heading beyond the cursor", function()
        assert_context("[[new|alias", #"[[n", 2, "n", false)
        assert_context("[[new#heading", #"[[n", 2, "n", false)
    end)

    it("is present before alias suffix without appending brackets", function()
        assert_context("[[foo|alias]]", #"[[foo", 2, "foo", false)
    end)

    it("is present before header suffix without appending brackets", function()
        assert_context("[[foo#heading]]", #"[[foo", 2, "foo", false)
    end)

    it("is absent after closed link", function()
        assert_no_context("[[foo]]", #"[[foo]]")
    end)

    it("is absent after alias separator", function()
        assert_no_context("[[foo|", #"[[foo|")
    end)

    it("is absent after header separator", function()
        assert_no_context("[[foo#", #"[[foo#")
    end)
end)

describe("completion items", function()
    local state = completion_fixture()

    local function set_line_and_cursor(line, cursor_col)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
        vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
    end

    it("finds start after opening brackets", function()
        Completion.setup(state.vault)
        set_line_and_cursor("[[ap", #"[[ap")

        local start_col = Completion.completefunc(1, "")

        assert.are.equal(completion_supported and 2 or -3, start_col)
    end)

    it("returns matching note names with closing brackets", function()
        state.create_file "apple.md"
        state.create_file "dir/apricot.md"
        state.create_file "banana.md"
        state.create_file "apricot.txt"
        Completion.setup(state.vault)
        set_line_and_cursor("[[ap", #"[[ap")

        local result = Completion.completefunc(0, "ap")

        if completion_supported then
            assert.list_size(result.words, 2)
            assert.are.equal("apple]]", result.words[1].word)
            assert.are.equal("apple", result.words[1].abbr)
            assert.are.equal("apricot]]", result.words[2].word)
            assert.are.equal("apricot", result.words[2].abbr)
        else
            assert.list_size(result.words, 0)
        end
        assert.are.equal("always", result.refresh)
    end)

    it("returns bare note names in the middle of a closed link", function()
        state.create_file "new.md"
        Completion.setup(state.vault)
        set_line_and_cursor("[[new]]", #"[[n")

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "n")

        if not completion_supported then
            assert.are.equal(-3, start_col)
            assert.list_size(result.words, 0)
            return
        end

        assert.are.equal(2, start_col)
        assert.list_size(result.words, 1)
        assert.are.equal("new", result.words[1].word)
        assert.are.equal("new", result.words[1].abbr)
    end)

    it("forms a closed wiki link when applied", function()
        state.create_file "apple.md"
        Completion.setup(state.vault)
        local line = "[[ap"
        local cursor_col = #"[[ap"
        set_line_and_cursor(line, cursor_col)

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "ap")

        if not completion_supported then
            assert.are.equal(-3, start_col)
            assert.list_size(result.words, 0)
            return
        end

        local applied = string.sub(line, 1, start_col)
            .. result.words[1].word
            .. string.sub(line, cursor_col + 1)
        assert.are.equal("[[apple]]", applied)
    end)

    it("does not offer candidates outside note buffers", function()
        state.create_file "apple.md"
        Completion.setup(state.vault)
        vim.bo.filetype = "text"
        set_line_and_cursor("[[ap", #"[[ap")

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "ap")

        assert.are.equal(-3, start_col)
        assert.list_size(result.words, 0)
    end)

    it("keeps existing wiki brackets around applied completion", function()
        state.create_file "foobar.md"
        Completion.setup(state.vault)
        local line = "[[foo]]"
        local cursor_col = #"[[foo"
        set_line_and_cursor(line, cursor_col)

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "foo")

        if not completion_supported then
            assert.are.equal(-3, start_col)
            assert.list_size(result.words, 0)
            return
        end

        local applied = string.sub(line, 1, start_col)
            .. result.words[1].word
            .. string.sub(line, cursor_col + 1)
        assert.are.equal("foobar", result.words[1].word)
        assert.are.equal("foobar", result.words[1].abbr)
        assert.are.equal("[[foobar]]", applied)
    end)

    it("keeps existing alias suffix around applied completion", function()
        state.create_file "foobar.md"
        Completion.setup(state.vault)
        local line = "[[foo|alias]]"
        local cursor_col = #"[[foo"
        set_line_and_cursor(line, cursor_col)

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "foo")

        if not completion_supported then
            assert.are.equal(-3, start_col)
            assert.list_size(result.words, 0)
            return
        end

        local applied = string.sub(line, 1, start_col)
            .. result.words[1].word
            .. string.sub(line, cursor_col + 1)
        assert.are.equal("foobar", result.words[1].word)
        assert.are.equal("foobar", result.words[1].abbr)
        assert.are.equal("[[foobar|alias]]", applied)
    end)

    it("keeps existing header suffix around applied completion", function()
        state.create_file "foobar.md"
        Completion.setup(state.vault)
        local line = "[[foo#heading]]"
        local cursor_col = #"[[foo"
        set_line_and_cursor(line, cursor_col)

        local start_col = Completion.completefunc(1, "")
        local result = Completion.completefunc(0, "foo")

        if not completion_supported then
            assert.are.equal(-3, start_col)
            assert.list_size(result.words, 0)
            return
        end

        local applied = string.sub(line, 1, start_col)
            .. result.words[1].word
            .. string.sub(line, cursor_col + 1)
        assert.are.equal("foobar", result.words[1].word)
        assert.are.equal("foobar", result.words[1].abbr)
        assert.are.equal("[[foobar#heading]]", applied)
    end)
end)

describe("completion acceptance", function()
    local state = completion_fixture()
    local saved_completeopt
    local saved_autocomplete

    before_each(function()
        saved_completeopt = vim.o.completeopt
        vim.o.completeopt = "menu,menuone,noselect"
        if completion_supported then
            saved_autocomplete = vim.o.autocomplete
            vim.o.autocomplete = false
        end
    end)

    after_each(function()
        vim.o.completeopt = saved_completeopt
        if completion_supported then
            vim.o.autocomplete = saved_autocomplete
        end
    end)

    local function prepare(line, cursor_col, note_name)
        state.create_file((note_name or "new") .. ".md")
        Completion.setup(state.vault)
        vim.bo.complete = Completion.complete_source
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
        vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
        -- Start a separate undo block for the simulated Insert command.
        vim.cmd "let &undolevels = &undolevels"
    end

    local function feed(keys)
        vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes(keys, true, false, true),
            "xt",
            false
        )
    end

    local cases = {
        { "same name", "[[new]]", #"[[n", "[[new]]" },
        { "different name", "[[next]]", #"[[n", "[[new]]" },
        { "alias", "[[next|alias]]", #"[[n", "[[new|alias]]" },
        { "heading", "[[next#heading]]", #"[[n", "[[new#heading]]" },
        { "unfinished alias", "[[next|alias", #"[[n", "[[new|alias" },
        { "unfinished heading", "[[next#head", #"[[n", "[[new#head" },
        { "immediate close", "[[n]]", #"[[n", "[[new]]" },
        { "open link", "[[n", #"[[n", "[[new]]" },
        {
            "multiple links",
            "[[old]] [[next]] [[last]]",
            #"[[old]] [[n",
            "[[old]] [[new]] [[last]]",
        },
        {
            "UTF-8 name and prefix",
            "текст [[новая]]",
            #"текст [[но",
            "текст [[новинка]]",
            "новинка",
        },
    }

    for _, case in ipairs(cases) do
        it("replaces the whole name with " .. case[1], function()
            if not completion_supported then
                return
            end
            prepare(case[2], case[3], case[5])
            -- An end-of-line insertion needs `a`, not `i` in Normal mode.
            local insert = case[3] == #case[2] and "a" or "i"
            feed(insert .. "<C-x><C-u><C-n><C-y><Esc>")

            assert.are.equal(case[4], vim.api.nvim_get_current_line())
        end)
    end

    it("uses the F source and keeps one undo block", function()
        if not completion_supported then
            return
        end
        prepare("[[next|alias]]", #"[[n")
        feed "i<C-n><C-n><C-y><Esc>"

        assert.are.equal("[[new|alias]]", vim.api.nvim_get_current_line())
        assert.are.same({ 1, #"[[new" - 1 }, vim.api.nvim_win_get_cursor(0))
        vim.cmd "undo"
        assert.are.equal("[[next|alias]]", vim.api.nvim_get_current_line())
        vim.cmd "redo"
        assert.are.equal("[[new|alias]]", vim.api.nvim_get_current_line())
    end)

    it("keeps a selected candidate on Escape", function()
        if not completion_supported then
            return
        end
        prepare("[[next]]", #"[[n")
        feed "i<C-x><C-u><C-n><Esc>"
        assert.are.equal("[[new]]", vim.api.nvim_get_current_line())
        vim.cmd "undo"
        assert.are.equal("[[next]]", vim.api.nvim_get_current_line())
        vim.cmd "redo"
        assert.are.equal("[[new]]", vim.api.nvim_get_current_line())
    end)

    it("keeps a selected candidate when typing continues", function()
        if not completion_supported then
            return
        end
        prepare("[[next]]", #"[[n")
        feed "i<C-x><C-u><C-n> <Esc>"
        assert.are.equal("[[new ]]", vim.api.nvim_get_current_line())
        vim.cmd "undo"
        assert.are.equal("[[next]]", vim.api.nvim_get_current_line())
        vim.cmd "redo"
        assert.are.equal("[[new ]]", vim.api.nvim_get_current_line())
    end)

    it("leaves the original link on cancellation", function()
        if not completion_supported then
            return
        end
        prepare("[[next|alias]]", #"[[n")
        feed "i<C-x><C-u><C-n><C-e><Esc>"
        assert.are.equal("[[next|alias]]", vim.api.nvim_get_current_line())
    end)

    it("leaves the original link without a selected candidate", function()
        if not completion_supported then
            return
        end
        prepare("[[next]]", #"[[n")
        feed "i<C-x><C-u><Esc>"
        assert.are.equal("[[next]]", vim.api.nvim_get_current_line())
    end)

    local function insert_candidate()
        prepare("[[next]]", #"[[n")
        local item = Completion.completefunc(0, "n").words[1]
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[newext]]" })
        vim.api.nvim_win_set_cursor(0, { 1, #"[[new" })
        return item
    end

    it("ignores a candidate from another provider", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        item.user_data = { other_provider = {} }

        Completion._on_complete_done(item, "accept")

        assert.are.equal("[[newext]]", vim.api.nvim_get_current_line())
    end)

    it("does not remove text after the completion context changes", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[newextra]]" })

        Completion._on_complete_done(item, "accept")

        assert.are.equal("[[newextra]]", vim.api.nvim_get_current_line())
    end)

    it("does not remove text after the cursor moves", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        vim.api.nvim_win_set_cursor(0, { 1, #"[[ne" })

        Completion._on_complete_done(item, "accept")

        assert.are.equal("[[newext]]", vim.api.nvim_get_current_line())
    end)

    it("does not apply an old candidate on another row", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        vim.api.nvim_buf_set_lines(0, 1, -1, false, { "[[newext]]" })
        vim.api.nvim_win_set_cursor(0, { 2, #"[[new" })

        Completion._on_complete_done(item, "accept")

        assert.are.same(
            { "[[newext]]", "[[newext]]" },
            vim.api.nvim_buf_get_lines(0, 0, -1, false)
        )
    end)

    it("does not apply an old candidate after disabling completion", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        Completion.disable()

        Completion._on_complete_done(item, "accept")

        assert.are.equal("[[newext]]", vim.api.nvim_get_current_line())
    end)

    it("does not apply an old candidate in another note buffer", function()
        if not completion_supported then
            return
        end
        local item = insert_candidate()
        local other_note = state.create_file "other.md"
        local other_bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(other_bufnr, other_note:path())
        vim.bo[other_bufnr].filetype = "markdown"
        vim.api.nvim_buf_set_lines(other_bufnr, 0, -1, false, { "[[newext]]" })

        vim.api.nvim_buf_call(other_bufnr, function()
            vim.api.nvim_win_set_cursor(0, { 1, #"[[new" })
            Completion._on_complete_done(item, "accept")
        end)

        local lines = vim.api.nvim_buf_get_lines(other_bufnr, 0, -1, false)
        vim.api.nvim_buf_delete(other_bufnr, { force = true })
        assert.are.same({ "[[newext]]" }, lines)
        assert.are.equal("[[newext]]", vim.api.nvim_get_current_line())
    end)
end)

describe("completion attach", function()
    local state = completion_fixture()

    local function complete_source_count()
        local count = 0
        for _, item in ipairs(vim.split(vim.bo.complete, ",", { plain = true })) do
            if item == Completion.complete_source then
                count = count + 1
            end
        end
        return count
    end

    it("adds complete source once", function()
        Completion.setup(state.vault)
        Completion.attach()

        assert.are.equal(
            completion_supported and 1 or 0,
            complete_source_count()
        )
    end)

    it("registers one completion handler across repeated setup", function()
        if not completion_supported then
            return
        end
        Completion.setup(state.vault)
        Completion.setup(state.vault)
        Completion.attach()

        assert.list_size(
            vim.api.nvim_get_autocmds {
                group = "ObsNvimCompletion",
                event = "CompleteDone",
            },
            1
        )

        Completion.disable()
        for _, autocmd in
            ipairs(vim.api.nvim_get_autocmds {
                event = "CompleteDone",
            })
        do
            assert.are_not.equal("ObsNvimCompletion", autocmd.group_name)
        end
    end)

    it("sets empty completefunc", function()
        Completion.setup(state.vault)

        assert.are.equal(
            completion_supported and Completion.completefunc_option or "",
            vim.bo.completefunc
        )
    end)

    it("does not overwrite user completefunc", function()
        vim.bo.completefunc = "UserComplete"

        Completion.setup(state.vault)

        assert.are.equal("UserComplete", vim.bo.completefunc)
    end)

    it("does not attach when disabled", function()
        Completion.setup(state.vault, { enabled = false })

        assert.are.equal(0, complete_source_count())
        assert.are.equal("", vim.bo.completefunc)
    end)

    it("does not attach to sibling vault path", function()
        state.sibling_home = Path:new(state.home:expand() .. "-old")
        local sibling_note_path = state.sibling_home / "current.md"
        sibling_note_path:touch()
        local sibling_note = File:new(sibling_note_path:expand())
        vim.cmd("edit " .. vim.fn.fnameescape(sibling_note:path()))
        vim.bo.filetype = "markdown"
        vim.bo.complete = default_complete
        vim.bo.completefunc = ""

        Completion.setup(state.vault)

        assert.are.equal(0, complete_source_count())
        assert.are.equal("", vim.bo.completefunc)
    end)
end)
