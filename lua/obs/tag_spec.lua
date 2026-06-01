local Tag = require "obs.tag"
require "obs.utils.spec"

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
