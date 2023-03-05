local Link = require "obs.link"
require "coredor.spec"

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
end)
