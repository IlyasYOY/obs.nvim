local Templater = require "obs.templater"
local spec_utils = require "obs.utils.spec"

describe("proccess files", function()
    local templater
    local temp_dir_data = spec_utils.temp_dir_fixture()

    it("no files", function()
        templater = Templater:new {
            home = temp_dir_data.path:expand(),
        }

        local templates = templater:list_templates()

        assert.list_size(templates, 0)
    end)

    it("not md", function()
        local kitty_file = temp_dir_data.path / "kitty.a"
        local hello_file = temp_dir_data.path / "hello.txt"
        kitty_file:touch {}
        hello_file:touch {}

        templater = Templater:new {
            home = temp_dir_data.path:expand(),
        }

        local templates = templater:list_templates()

        assert.list_size(templates, 0)
    end)

    it("md", function()
        local kitty_file = temp_dir_data.path / "kitty.md"
        local hello_file = temp_dir_data.path / "hello.md"
        kitty_file:touch {}
        hello_file:touch {}

        templater = Templater:new {
            home = temp_dir_data.path:expand(),
        }

        local templates = templater:list_templates()

        assert.list_size(templates, 2)
    end)

    it("entry structure", function()
        local kitty_file = temp_dir_data.path / "kitty.md"
        kitty_file:touch {}

        templater = Templater:new {
            home = temp_dir_data.path:expand(),
        }

        local templates = templater:list_templates()

        assert.list_size(templates, 1)
        assert.file(templates[1], "kitty", vim.fn.resolve(kitty_file:expand()))
    end)
end)

describe("process string", function()
    local templater
    local template
    local result

    it("empty string", function()
        template = ""
        templater = Templater:new {}

        result = templater:_process_for_current_buffer(template)

        assert.are.equal("", result)
    end)

    it("templates present", function()
        template = "Simple template with {{date}}"
        templater = Templater:new()

        result = templater:_process_for_current_buffer(template)

        assert.are_not.equal(template, result, "string was not templated")
    end)

    it("templates work", function()
        template = "Simple template with {{date}}"
        templater = Templater:new {}
        templater:add_var_provider("date", function()
            return "2022-12-31"
        end)

        result = templater:_process_for_current_buffer(template)

        assert.are.equal(
            "Simple template with 2022-12-31",
            result,
            "tempate processing is wrong"
        )
    end)

    it("multiple work complex case", function()
        template = "Simple template with {{date}} {{title}}"
        templater = Templater:new {}
        templater:add_var_provider("date", function()
            return "2022-12-31"
        end)
        templater:add_var_provider("title", function()
            return "Cool Title"
        end)

        result = templater:_process_for_current_buffer(template)

        assert.are.equal(
            "Simple template with 2022-12-31 Cool Title",
            result,
            "templates were not resolved"
        )
    end)

    it("templates may be overriden", function()
        template = "Simple template with {{date}}"
        templater = Templater:new {}
        templater:add_var_provider("date", function()
            return "2022-12-31"
        end)
        templater:add_var_provider("date", function()
            return "2022-12-30"
        end)

        result = templater:_process_for_current_buffer(template)

        assert.are.equal(
            "Simple template with 2022-12-30",
            result,
            "template was not overriden"
        )
    end)

    --  Tests of users extra_providers

    it("can be initialized with extra_providers in opts", function()
        local templater = Templater:new {
            home = ".",
            extra_providers = {
                {
                    name = "callme",
                    func = function() return "custom_val" end
                }
            }
        }

        local result = templater:process({ template = "Value: {{callme}}" })

        assert.are.equal(
            "Value: custom_val",
            result,
            "extra_providers from opts were not registered"
        )
    end)

    it("does not call provider function if tag is not in template (lazy evaluation)", function()
        local call_count = 0
        local templater = Templater:new {
            home = ".",
            extra_providers = {
                {
                    name = "callme",
                    func = function()
                        call_count = call_count + 1
                        return "input"
                    end
                }
            }
        }
        -- case 1  not tag - not call 
        local _ = templater:process({ template = "No tags here" })
        assert.are.equal(0, call_count, "Provider function was called unexpectedly")

        -- case 2  tag is - call is 
        local result = templater:process({ template = "Tag: {{callme}}" })
        assert.are.equal(1, call_count, "Provider function should be called exactly once")
        assert.are.equal("Tag: input", result)
    end)

   it("calls provider only once for multiple occurrences of the same tag", function()
    local call_count = 0
    local templater = Templater:new {
        home = ".",
        extra_providers = {
            {
                name = "multi",
                func = function() 
                    call_count = call_count + 1
                    return "val" 
                end
            }
        }
    }

    local template = "{{multi}} {{multi}} {{multi}}"
    local result = templater:process({ template = template })

    assert.are.equal("val val val", result)
    assert.are.equal(1, call_count, "Provider should be called exactly once for all occurrences")
  end)
end)
