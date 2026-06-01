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
