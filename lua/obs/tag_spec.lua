local Tag = require "obs.tag"
require "obs.utils.spec"

describe("normalize tag", function()
    it("strips leading hashes, quotes, and space", function()
        assert.are.equal("work", Tag.normalize [[ "#work" ]])
        assert.are.equal("work", Tag.normalize "work")
        assert.is_nil(Tag.normalize "#")
        assert.is_nil(Tag.normalize "")
    end)

    it("rejects all-numeric tags", function()
        assert.is_nil(Tag.normalize "#123")
        assert.is_nil(Tag.normalize "123")
        assert.are.equal("123abc", Tag.normalize "#123abc")
    end)
end)

describe("find tag at position", function()
    it("finds a tag under the cursor", function()
        local text = "before #work after"
        local tag_start = string.find(text, "#work", 1, true)

        assert.are.equal("work", Tag.find_at(text, tag_start))
        assert.are.equal("work", Tag.find_at(text, tag_start + 2))
    end)

    it("does not find a tag outside the cursor position", function()
        local text = "before #work after"

        assert.is_nil(Tag.find_at(text, 1))
    end)

    it("finds slashed tags", function()
        local text = "before #parent/child after"
        local tag_start = string.find(text, "child", 1, true)

        assert.are.equal("parent/child", Tag.find_at(text, tag_start))
    end)

    it("does not find all-numeric tags", function()
        local text = "Issue #123"
        local tag_start = string.find(text, "#123", 1, true)

        assert.is_nil(Tag.find_at(text, tag_start))
    end)

    it("ignores tags inside brackets and fenced code", function()
        local bracket_text = "[#ignored] #real"
        local bracket_tag = string.find(bracket_text, "#ignored", 1, true)
        local real_tag = string.find(bracket_text, "#real", 1, true)

        assert.is_nil(Tag.find_at(bracket_text, bracket_tag))
        assert.are.equal("real", Tag.find_at(bracket_text, real_tag))

        local fence_text = table.concat({
            "```lua",
            "#ignored",
            "```",
        }, "\n")
        local fence_tag = string.find(fence_text, "#ignored", 1, true)

        assert.is_nil(Tag.find_at(fence_text, fence_tag))
    end)

    it("ignores tags inside inline code", function()
        local text = "Use `#ignored` before #real"
        local code_tag = string.find(text, "#ignored", 1, true)
        local real_tag = string.find(text, "#real", 1, true)

        assert.is_nil(Tag.find_at(text, code_tag))
        assert.are.equal("real", Tag.find_at(text, real_tag))
    end)

    it("finds non-ASCII tags", function()
        local text = "before #работа after"
        local tag_start = string.find(text, "#работа", 1, true)
        local tag_middle = string.find(text, "бота", 1, true)

        assert.are.equal("работа", Tag.find_at(text, tag_start))
        assert.are.equal("работа", Tag.find_at(text, tag_middle))
    end)
end)

describe("tags from text", function()
    it("returns no tags for empty text", function()
        assert.same({}, Tag.from_text "")
    end)

    it("parses YAML array tags before body tags", function()
        local text = table.concat({
            "---",
            "tags: [foo, \"#bar\", 'baz/qux']",
            "---",
            "#body",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "foo", "bar", "baz/qux", "body" }, tags)
    end)

    it("parses YAML scalar tags", function()
        local text = table.concat({
            "---",
            "tags: foo #bar baz/qux",
            "---",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "foo", "bar", "baz/qux" }, tags)
    end)

    it("parses YAML block list tags", function()
        local text = table.concat({
            "---",
            "tags:",
            "  - foo",
            [[  - "#bar"]],
            "other:",
            "  - not-a-tag",
            "---",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "foo", "bar" }, tags)
    end)

    it("parses inline tags with punctuation boundaries", function()
        local text = table.concat({
            "#one, (#two). #parent/child #tag-name #tag_name;",
            "foo#skip [[note#header]] https://example.com/#anchor",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({
            "one",
            "two",
            "parent/child",
            "tag-name",
            "tag_name",
        }, tags)
    end)

    it("ignores all-numeric inline tags", function()
        local tags = Tag.from_text "Issue #123 and PR #456, but #work remains"

        assert.same({ "work" }, tags)
    end)

    it("parses non-ASCII inline tags", function()
        local tags =
            Tag.from_text "#работа #プロジェクト #дело/проект #тег-name, #work"

        assert.same({
            "работа",
            "プロジェクト",
            "дело/проект",
            "тег-name",
            "work",
        }, tags)
    end)

    it("rejects inline tags after non-ASCII tag characters", function()
        local tags = Tag.from_text "слово#skip #real"

        assert.same({ "real" }, tags)
    end)

    it("ignores inline tags inside Markdown link labels", function()
        local text = "Сделал новью небольшую доработку в Minuet, получилось интересно: "
            .. "[feat: add Fidget component for displaying Minuet request status "
            .. "by IlyasYOY · Pull Request #99 · milanglacier/minuet-ai.nvim]"
            .. "(https://github.com/milanglacier/minuet-ai.nvim/pull/99). "
            .. "Надеюсь, что она попадет в main."

        local tags = Tag.from_text(text)

        assert.same({}, tags)
    end)

    it("ignores inline tags inside balanced brackets", function()
        local tags = Tag.from_text "[this is #not-a-tag]"

        assert.same({}, tags)
    end)

    it("keeps inline tags outside balanced brackets", function()
        local tags = Tag.from_text "#real [#ignored] #also-real"

        assert.same({ "real", "also-real" }, tags)
    end)

    it("does not ignore inline tags after unmatched opening bracket", function()
        local tags = Tag.from_text "[before #tag"

        assert.same({ "tag" }, tags)
    end)

    it("ignores inline tags inside fenced code blocks", function()
        local text = table.concat({
            "#outside",
            "```lua",
            "if #tags > 3 then",
            '    print "#ignored"',
            "end",
            "```",
            "#after",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "outside", "after" }, tags)
    end)

    it("ignores inline tags inside inline code", function()
        local tags =
            Tag.from_text "Use `#include` and ``#todo`` before #real `#kept"

        assert.same({ "real", "kept" }, tags)
    end)

    it("deduplicates tags in first-seen order", function()
        local text = table.concat({
            "---",
            "tags: [#one, two]",
            "---",
            "#one #two #three #three",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "one", "two", "three" }, tags)
    end)

    it("ignores frontmatter that does not start the note", function()
        local text = table.concat({
            "Intro",
            "---",
            "tags: [yaml]",
            "---",
            "#body",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "body" }, tags)
    end)

    it("ignores unterminated frontmatter", function()
        local text = table.concat({
            "---",
            "tags: [yaml]",
            "#body",
        }, "\n")

        local tags = Tag.from_text(text)

        assert.same({ "body" }, tags)
    end)
end)
