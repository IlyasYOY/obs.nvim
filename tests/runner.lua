local M = {}

local tests = {}
local stack = {}
local hook_stack = {}

local native_assert = _G.assert

local function reset_hooks()
    hook_stack = {
        {
            before_each = {},
            after_each = {},
        },
    }
end

reset_hooks()

local function collect_hooks(kind)
    local result = {}
    for _, hooks in ipairs(hook_stack) do
        for _, fn in ipairs(hooks[kind]) do
            result[#result + 1] = fn
        end
    end
    return result
end

local function fullname(name)
    local parts = vim.deepcopy(stack)
    parts[#parts + 1] = name
    return table.concat(parts, " ")
end

function _G.describe(name, fn)
    stack[#stack + 1] = name
    hook_stack[#hook_stack + 1] = {
        before_each = {},
        after_each = {},
    }

    local ok, err = xpcall(fn, debug.traceback)

    hook_stack[#hook_stack] = nil
    stack[#stack] = nil

    if not ok then
        error(err, 0)
    end
end

function _G.it(name, fn)
    tests[#tests + 1] = {
        name = fullname(name),
        fn = fn,
        before_each = collect_hooks "before_each",
        after_each = collect_hooks "after_each",
    }
end

function _G.before_each(fn)
    local hooks = hook_stack[#hook_stack]
    hooks.before_each[#hooks.before_each + 1] = fn
end

function _G.after_each(fn)
    local hooks = hook_stack[#hook_stack]
    hooks.after_each[#hooks.after_each + 1] = fn
end

local function fail(message, level)
    error(message, (level or 1) + 1)
end

local function inspect(value)
    return vim.inspect(value)
end

local function equal(expected, actual, message)
    if expected ~= actual then
        fail(
            message
                or (
                    "expected "
                    .. inspect(expected)
                    .. ", got "
                    .. inspect(actual)
                ),
            2
        )
    end
end

local function not_equal(expected, actual, message)
    if expected == actual then
        fail(
            message or ("expected value not to equal " .. inspect(expected)),
            2
        )
    end
end

local function same(expected, actual, message)
    if not vim.deep_equal(expected, actual) then
        fail(
            message
                or (
                    "expected "
                    .. inspect(expected)
                    .. ", got "
                    .. inspect(actual)
                ),
            2
        )
    end
end

local function truthy(value, message)
    if not value then
        fail(message or ("expected truthy value, got " .. inspect(value)), 2)
    end
end

local function falsy(value, message)
    if value then
        fail(message or ("expected falsy value, got " .. inspect(value)), 2)
    end
end

local function is_true(value, message)
    if value ~= true then
        fail(message or ("expected true, got " .. inspect(value)), 2)
    end
end

local function is_false(value, message)
    if value ~= false then
        fail(message or ("expected false, got " .. inspect(value)), 2)
    end
end

local function is_nil(value, message)
    if value ~= nil then
        fail(message or ("expected nil, got " .. inspect(value)), 2)
    end
end

local function is_not_nil(value, message)
    if value == nil then
        fail(message or "expected non-nil value, got nil", 2)
    end
end

local function has_error(fn, expected)
    local ok, err = pcall(fn)
    if ok then
        fail("expected function to error", 2)
    end

    if expected ~= nil and not tostring(err):find(expected, 1, true) then
        fail(
            ("expected error containing %s, got %s"):format(
                inspect(expected),
                inspect(err)
            ),
            2
        )
    end

    return err
end

local assert_table = setmetatable({}, {
    __call = function(_, value, message)
        return native_assert(value, message)
    end,
})

assert_table.equal = equal
assert_table.equals = equal
assert_table.same = same
assert_table.not_equal = not_equal
assert_table.truthy = truthy
assert_table.falsy = falsy
assert_table.True = is_true
assert_table.False = is_false
assert_table.Falsy = falsy
assert_table.is_true = is_true
assert_table.is_false = is_false
assert_table.is_nil = is_nil
assert_table.is_not_nil = is_not_nil
assert_table.has_error = has_error
assert_table.number = function(value)
    if type(value) ~= "number" then
        fail("expected number, got " .. inspect(value), 2)
    end
end

assert_table.are = assert_table
assert_table.is = assert_table
assert_table.are_not = {
    equal = not_equal,
    equals = not_equal,
    same = function(expected, actual, message)
        if vim.deep_equal(expected, actual) then
            fail(
                message or ("expected value not to equal " .. inspect(expected)),
                2
            )
        end
    end,
}

_G.assert = assert_table

local function load_files(files)
    local failures = {}

    for _, file in ipairs(files) do
        reset_hooks()
        local ok, err = xpcall(function()
            dofile(file)
        end, debug.traceback)

        if not ok then
            failures[#failures + 1] = {
                name = "load " .. file,
                err = err,
            }
        end
    end

    return failures
end

local function default_files()
    local files =
        vim.fn.globpath(vim.fn.getcwd(), "lua/**/*_spec.lua", true, true)
    table.sort(files)
    return files
end

local function normalize_files(files)
    if files == nil then
        return default_files()
    end

    local result = {}
    for _, file in ipairs(files) do
        if vim.fn.fnamemodify(file, ":p") == file then
            result[#result + 1] = file
        else
            result[#result + 1] = vim.fn.fnamemodify(file, ":p")
        end
    end
    table.sort(result)
    return result
end

local function run_test(test)
    for _, fn in ipairs(test.before_each) do
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then
            return false, err
        end
    end

    local ok, err = xpcall(test.fn, debug.traceback)

    for index = #test.after_each, 1, -1 do
        local hook_ok, hook_err =
            xpcall(test.after_each[index], debug.traceback)
        if not hook_ok then
            if ok then
                ok = false
                err = hook_err
            else
                err = err .. "\n" .. hook_err
            end
        end
    end

    return ok, err
end

local function run_registered_tests(opts)
    local failures = {}

    for _, test in ipairs(tests) do
        local ok, err = run_test(test)

        if ok then
            if opts.verbose then
                print("ok - " .. test.name)
            end
        else
            failures[#failures + 1] = {
                name = test.name,
                err = err,
            }
            print("not ok - " .. test.name)
            print(err)
        end
    end

    return failures, #tests
end

function M.run(opts)
    opts = opts or {}

    tests = {}
    reset_hooks()

    local files = normalize_files(opts.files)
    local failures = load_files(files)

    for _, failure in ipairs(failures) do
        print("not ok - " .. failure.name)
        print(failure.err)
    end

    local test_failures, count = run_registered_tests(opts)
    for _, failure in ipairs(test_failures) do
        failures[#failures + 1] = failure
    end

    print(("%d test(s) run"):format(count))

    if #failures > 0 then
        print(("%d test(s) failed"):format(#failures))
        vim.cmd "cquit 1"
    end
end

return M
