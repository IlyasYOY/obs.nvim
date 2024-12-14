local utils = require "obs.utils"
local spec = require "obs.utils.spec"

describe("list directories", function()
    local list_directories = utils.list_folders
    local temp_file_fixture = spec.temp_file_fixture()
    local temp_dir_fixture = spec.temp_dir_fixture()

    it("nil parameter causes error", function()
        assert.has_error(function()
            list_directories()
        end, "path must not be nil")
    end)

    it("not existing directory causes error", function()
        local invalid_directory_path = "invalid directory " .. utils.uuid()

        assert.has_error(function()
            list_directories(invalid_directory_path)
        end, "path '" .. invalid_directory_path .. "' must exist")
    end)

    it("not directory causes error", function()
        local file_path = temp_file_fixture.path:expand()

        assert.has_error(function()
            list_directories(file_path)
        end, "path '" .. file_path .. "' must point to directory, not a file")
    end)

    it("get current directory", function()
        local temp_dir_path = temp_dir_fixture.path:expand()

        local result = list_directories(temp_dir_path)

        assert.is_not_nil(result)
        assert.list_size(result, 1)
        assert.are.equal(temp_dir_path, result[1])
    end)

    it("get current directory with nested directory", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir = temp_dir_fixture.path / utils.uuid()
        nested_dir:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 2)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert.are.equal(nested_dir:expand(), result[2])
    end)

    it("get current directory with 2 nested directories", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / utils.uuid()
        nested_dir1:mkdir()
        local nested_dir2 = temp_dir_fixture.path / utils.uuid()
        nested_dir2:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 3)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert(
            nested_dir1:expand() == result[2]
                    and nested_dir2:expand() == result[3]
                or nested_dir1:expand() == result[3]
                    and nested_dir2:expand() == result[2]
        )
    end)

    it("get current directory with 2 inner nested directories", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / utils.uuid()
        nested_dir1:mkdir()
        local nested_dir2 = nested_dir1 / utils.uuid()
        nested_dir2:mkdir()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 3)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert(
            nested_dir1:expand() == result[2]
                    and nested_dir2:expand() == result[3]
                or nested_dir1:expand() == result[3]
                    and nested_dir2:expand() == result[2]
        )
    end)

    it("get current directory with nested directory and file", function()
        local temp_dir_path = temp_dir_fixture.path
        local nested_dir1 = temp_dir_fixture.path / utils.uuid()
        nested_dir1:mkdir()
        local nested_file = temp_dir_fixture.path / utils.uuid()
        nested_file:touch()

        local result = list_directories(temp_dir_path:expand())

        assert.is_not_nil(result)
        assert.list_size(result, 2)
        assert.are.equal(temp_dir_path:expand(), result[1])
        assert.are.equal(nested_dir1:expand(), result[2])
    end)

    local urlencode = utils.urlencode
    local urldecode = utils.urldecode
    it("url encode", function()
        local result = urlencode "привет мир"

        assert.are.equal(
            "%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%D0%BC%D0%B8%D1%80",
            result
        )
    end)

    it("url decode", function()
        local result =
            urldecode "%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%D0%BC%D0%B8%D1%80"

        assert.are.equal("привет мир", result)
    end)

    it("url decode/encode", function()
        local str = "%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%D0%BC%D0%B8%D1%80"
        local decoded = urldecode(str)
        local encoded = urlencode(decoded)
        assert.are.equal(str, encoded)
    end)
end)
describe("string", function()
    describe("has suffix", function()
        it("nil parameter", function()
            assert.is_false(
                utils.string_has_suffix("test", nil),
                "must returns nil when parameter is nil"
            )
        end)

        for _, str in ipairs {
            "test.txt",
            "test.md.txt",
            "testmd",
        } do
            it("'" .. str .. "' is false for '.md' suffix", function()
                assert.is_false(
                    utils.string_has_suffix(str, ".md", true),
                    "prefix was found even though it was absent"
                )
            end)
        end

        it("is true", function()
            assert.is_true(
                utils.string_has_suffix("test.txt", ".txt", true),
                "prefix was not found"
            )
        end)
    end)

    describe("split", function()
        local string_split = utils.string_split

        local function check_hello_world_split(split)
            assert.are.equal(2, #split, "string should be spit in two words")
            assert.are.equal("hello", split[1], "first word is wrong")
            assert.are.equal("world", split[2], "second word is wrong")
        end

        it("no splits found", function()
            local result = string_split("hello world", "x")
            assert.are.equal(
                1,
                #result,
                "string should not be split, but it was"
            )
            assert.are.equal(
                "hello world",
                result[#result],
                "string itself is the only element of the array"
            )
        end)

        it("works with space", function()
            local result = string_split("hello world", " ")
            check_hello_world_split(result)
        end)

        it("works with .", function()
            local result = string_split("hello.world", ".")
            check_hello_world_split(result)
        end)

        it("work with new line separator", function()
            local result = string_split("hello\nworld", "\n")
            check_hello_world_split(result)
        end)
    end)

    describe("starts with", function()
        local starts_with = utils.string_has_prefix

        it("prefix param is nil", function()
            local result = starts_with("abc test", nil)
            assert.is_false(result, "false must be returned on nil input")
        end)

        it("found prefix", function()
            local result = starts_with("abc test", "abc")
            assert.is_true(result, "prefix must be found")
        end)

        for _, str in ipairs {
            "test abc ",
            "test abcd",
        } do
            it("'abc' not prefix of '" .. str .. "'", function()
                local result = starts_with(str, "abc")
                assert.is_false(
                    result,
                    "prefix should not be found, string not in the end"
                )
            end)
        end
    end)

    describe("strip prefix", function()
        local strip_prefix = utils.string_strip_prefix

        it("not in prefix", function()
            local result = strip_prefix("aaa abc", "abc")
            assert.are.equal(
                "aaa abc",
                result,
                "string is no in prefix, it's suffix"
            )
        end)

        it("not in string", function()
            local result = strip_prefix("aaa bbb", "abc")
            assert.are.equal("aaa bbb", result, "prefix should not be found in")
        end)

        it("remove prefix ", function()
            local result = strip_prefix("abc aaa", "abc")
            assert.are.equal(" aaa", result, "prefix was removed incorrectly")
        end)
    end)
end)

describe("array operation", function()
    local map = utils.array_map

    describe("map", function()
        for name, case in pairs {
            empty = {
                input = {},
                expected = {},
            },
            singleton = {
                input = { 1 },
                expected = { 2 },
            },
            big = {
                input = { 1, 7, 16 },
                expected = { 2, 14, 32 },
            },
        } do
            it(name .. " list", function()
                local result = map(case.input, function(x)
                    return x * 2
                end)
                assert.is_true(vim.deep_equal(result, case.expected))
            end)
        end
    end)

    describe("filter", function()
        local filter = utils.array_filter

        for name, case in pairs {
            empty = {
                input = {},
                expected = {},
            },
            ["singleton not passes"] = {
                input = { 1 },
                expected = {},
            },
            ["singleton passes"] = {
                input = { 2 },
                expected = { 2 },
            },
            ["some pass some not"] = {
                input = { 1, 7, 8, 4, 9, 10 },
                expected = { 8, 4, 10 },
            },
        } do
            it(name .. " list", function()
                local result = filter(case.input, function(x)
                    return x % 2 == 0
                end)
                assert.is_true(vim.deep_equal(result, case.expected))
            end)
        end
    end)

    describe("flat_map", function()
        local flat_map = utils.array_flat_map

        for name, case in pairs {
            empty = {
                input = {},
                expected = {},
            },
            ["single item"] = {
                input = { 2 },
                expected = { 2, 4 },
            },
            ["multiple items"] = {
                input = { 2, 7, 3 },
                expected = { 2, 4, 7, 14, 3, 6 },
            },
        } do
            it(name .. " list", function()
                local result = flat_map(case.input, function(x)
                    return { x, x * 2 }
                end)
                assert.is_true(
                    vim.deep_equal(result, case.expected),
                    string.format(
                        "Expected %s, but was %s",
                        vim.inspect(case.expected),
                        vim.inspect(result)
                    )
                )
            end)
        end
    end)
end)
