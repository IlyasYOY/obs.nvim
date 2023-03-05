local Templater = require "obs.templater"
local spec_utils = require "coredor.spec"

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
        assert.file(templates[1], "kitty", kitty_file:expand())
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
end)
