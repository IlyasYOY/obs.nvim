local Link = require "obs.link"
require "obs.utils.spec"

---@param link obs.Link
---@param header string?
local function assert_link_header(link, header)
    assert.are.equal(header, link.header, "wrong link header")
end

---@param link obs.Link
---@param alias string?
local function assert_link_alias(link, alias)
    assert.are.equal(alias, link.alias, "wrong link alias")
end

---@param link obs.Link
---@param name string?
local function assert_link_name(link, name)
    assert.are.equal(name, link.name, "wrong link name")
end

---@param link obs.Link
---@param name string?
---@param header string?
---@param alias string?
local function assert_link(link, name, header, alias)
    assert_link_name(link, name)
    assert_link_alias(link, header)
    assert_link_header(link, alias)
end

describe("from text", function()
    it("empty text", function()
        local result = Link.from_text ""

        assert.is_not_nil(result)
        assert.list_size(result, 0)
    end)

    it("single link", function()
        local result = Link.from_text "[[name]]"

        assert.is_not_nil(result)
        assert.list_size(result, 1)
        assert_link(result[1], "name")
    end)

    it("one-character link", function()
        local result = Link.from_text "[[a]]"

        assert.is_not_nil(result)
        assert.list_size(result, 1)
        assert_link(result[1], "a")
    end)

    it("multiple links", function()
        local result = Link.from_text "[[name]] [[full name|not really]]"
        assert.is_not_nil(result)
        assert.list_size(result, 2)
        assert_link(result[1], "name")
        assert_link(result[2], "full name", "not really")
    end)
end)

describe("from string", function()
    for _, wrong_link in ipairs {
        "[[kek",
        "cheburek]]",
        "[[burek]]",
        "]]che]]",
    } do
        it("'" .. wrong_link .. "' is wrong link", function()
            local result = Link.from_string(wrong_link)
            assert.is_nil(result, "link should not pass validation")
        end)
    end

    it("empty string", function()
        local result = Link.from_string ""
        assert.is_nil(result)
    end)

    it("raw link", function()
        local result = Link.from_string "name"
        assert.is_not_nil(result)
        assert(result)
        assert_link(result, "name")
    end)

    it("one-character raw link", function()
        local result = Link.from_string "a"
        assert.is_not_nil(result)
        assert(result)
        assert_link(result, "a")
    end)

    for _, header in ipairs {
        "header",
        "big header",
    } do
        it("with header '" .. header .. "'", function()
            local result = Link.from_string("name#" .. header)
            assert.is_not_nil(result ~= nil)
            assert(result)
            assert_link(result, "name", nil, header)
        end)
    end

    for _, alias in ipairs {
        "alias",
        "big alias",
    } do
        it("with alias '" .. alias .. "'", function()
            local result = Link.from_string("name|" .. alias)
            assert.is_not_nil(result)
            assert(result)
            assert_link(result, "name", alias, nil)
        end)
    end
end)

describe("find link", function()
    local find_link = Link.find_link_at

    it("no link", function()
        local link = find_link("123 [[he 345", 6)
        assert.is_nil(link, "link should not be found")
    end)

    it("miss link", function()
        local link = find_link("123 [[hello]] 345", 2)
        assert.is_nil(link, "link should not be found")
    end)

    for _, num in ipairs { 7, 9, 11 } do
        it("has link with " .. num .. " index", function()
            local link = find_link("123 [[hello]] 345", num)
            assert.is_not_nil(link)
            assert(link)
            assert_link(link, "hello")
        end)
    end

    it("has one-character link", function()
        local link = find_link("[[a]]", 3)
        assert.is_not_nil(link)
        assert(link)
        assert_link(link, "a")
    end)
end)

describe("find links in line", function()
    local find_links = Link.find_links_in_line

    it("finds wiki link spans", function()
        local line = "pre [[one]] and [[two|alias]]"
        local result = find_links(line, false)

        assert.list_size(result, 2)
        assert.are.equal("wiki", result[1].type)
        assert.are.equal(
            "[[one]]",
            string.sub(line, result[1].start_col + 1, result[1].end_col + 1)
        )
        assert.are.equal("one", result[1].link.name)
        assert.are.equal(
            "o",
            string.sub(line, result[1].cursor_col + 1, result[1].cursor_col + 1)
        )

        assert.are.equal("wiki", result[2].type)
        assert.are.equal("two", result[2].link.name)
        assert.are.equal("alias", result[2].link.alias)
    end)

    it("includes Markdown links only when requested", function()
        local line = "[doc](doc.md) and [[wiki]]"

        local wiki_only = find_links(line, false)
        local all_links = find_links(line, true)

        assert.list_size(wiki_only, 1)
        assert.are.equal("wiki", wiki_only[1].type)
        assert.list_size(all_links, 2)
        assert.are.equal("markdown", all_links[1].type)
        assert.are.equal("doc", all_links[1].text)
        assert.are.equal("doc.md", all_links[1].target)
        assert.are.equal(
            "d",
            string.sub(
                line,
                all_links[1].cursor_col + 1,
                all_links[1].cursor_col + 1
            )
        )
        assert.are.equal("wiki", all_links[2].type)
    end)

    it("includes bare http and https links only when requested", function()
        local line = "see http://example.com and https://example.org/path"

        local wiki_only = find_links(line, false)
        local all_links = find_links(line, true)

        assert.list_size(wiki_only, 0)
        assert.list_size(all_links, 2)
        assert.are.equal("url", all_links[1].type)
        assert.are.equal("http://example.com", all_links[1].target)
        assert.are.equal(
            "h",
            string.sub(
                line,
                all_links[1].cursor_col + 1,
                all_links[1].cursor_col + 1
            )
        )
        assert.are.equal("url", all_links[2].type)
        assert.are.equal("https://example.org/path", all_links[2].target)
    end)

    it("orders wiki, Markdown, and bare URL links by position", function()
        local line = "[[wiki]] [doc](doc.md) https://example.com"
        local result = find_links(line, true)

        assert.list_size(result, 3)
        assert.are.equal("wiki", result[1].type)
        assert.are.equal("markdown", result[2].type)
        assert.are.equal("url", result[3].type)
    end)

    it("trims trailing punctuation from bare URLs", function()
        local result = find_links(
            "Visit https://example.com/path, then http://example.org/.",
            true
        )

        assert.list_size(result, 2)
        assert.are.equal("https://example.com/path", result[1].target)
        assert.are.equal("http://example.org/", result[2].target)
    end)

    it("does not duplicate URLs inside Markdown links", function()
        local result = find_links("[site](https://example.com)", true)

        assert.list_size(result, 1)
        assert.are.equal("markdown", result[1].type)
        assert.are.equal("https://example.com", result[1].target)
    end)

    it("treats Markdown image syntax as a Markdown link span", function()
        local line = "![link](https://vk.com/)"
        local result = find_links(line, true)

        assert.list_size(result, 1)
        assert.are.equal("markdown", result[1].type)
        assert.are.equal("link", result[1].text)
        assert.are.equal("https://vk.com/", result[1].target)
        assert.are.equal(
            "l",
            string.sub(line, result[1].cursor_col + 1, result[1].cursor_col + 1)
        )
    end)

    it("does not include reference or other URI links", function()
        local result = find_links(
            "[ref][id] ftp://example.com mailto:name@example.com",
            true
        )

        assert.list_size(result, 0)
    end)
end)
