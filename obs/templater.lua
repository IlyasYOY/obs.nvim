local Path = require "plenary.path"
local core = require "coredor"
local File = require "coredor.file"
local telescope = require "obs.telescope"

-- options for VarProvider
---@class obs.VarProviderOpts
---@field filename string?

-- simple table to provide values for template
---@class obs.VarProvider
---@field public name string
---@field public func fun(VarProviderOpts?):string

-- options to run tempalating
---@class obs.TemplaterProcessingOpts
---@field public template string?
---@field public template_name string?
---@field public filename string?

-- options to create templater
---@class obs.TemplaterOpts
---@field public include_default_providers? boolean
---@field public home string
local TemplaterOpts = {}
TemplaterOpts.__index = TemplaterOpts

function TemplaterOpts:new(opts)
    opts = opts or {}
    local this = setmetatable(
        vim.tbl_extend("force", {
            include_default_providers = true,
        }, opts),
        self
    )
    return this
end

-- class to run templating
---@class obs.Templater
---@field private _var_providers obs.VarProvider[]
---@field private _home_path Path to the tamplates directory
local Templater = {}

-- create new Templater instance
---@param opts obs.TemplaterOpts
---@return obs.Templater instance
function Templater:new(opts)
    opts = opts or TemplaterOpts:new(opts)

    self.__index = self
    local templater = setmetatable({}, self)

    templater._var_providers = {}

    ---@type Path
    templater._home_path = Path:new(opts.home)

    if opts.include_default_providers then
        templater:add_var_provider("date", function()
            local result = os.date "%Y-%m-%d"
            return result
        end)
        templater:add_var_provider("title", function(context)
            local filename = context.filename
            return core.string_strip_suffix(filename, ".md")
        end)
    end

    return templater
end

---seach for the template in vault and inserts expanded value
function Templater:search_and_insert_template()
    local templates = self:list_templates()
    return telescope.find_through_items(
        "Templates",
        templates,
        function(selection)
            local selected_file = selection.value
            local templated_lines = core.lines_from(
                selected_file,
                function(line)
                    return self:_process_for_current_buffer(line)
                end
            )
            vim.api.nvim_put(templated_lines, "", true, true)
        end,
        function(entry)
            return {
                value = entry:path(),
                display = entry:name(),
                ordinal = entry:name(),
            }
        end
    )
end

-- lists templates
---@return coredor.File[]
function Templater:list_templates()
    local home_path_string = self._home_path:expand()
    return File.list(home_path_string, "*.md")
end

-- adds template variable for processing.
---@param name string
---@param func fun(VarProviderOpts?):string
function Templater:add_var_provider(name, func)
    for _, var_provider in pairs(self._var_providers) do
        if name == var_provider.name then
            var_provider.func = func
            return
        end
    end
    local new_provider = { name = name, func = func }
    table.insert(self._var_providers, new_provider)
end

-- performs templating.
---@param opts obs.TemplaterProcessingOpts
---@return string templated string
function Templater:process(opts)
    opts = opts or {}

    local template = opts.template
        or self:_get_raw_template_content(opts.template_name)

    if not template then
        error(
            "must have template or template_name specified but was "
                .. vim.inspect(opts)
        )
    end

    for _, var_provider in ipairs(self._var_providers) do
        local name = var_provider.name
        local func = var_provider.func
        local res = func { filename = opts.filename }
        template = string.gsub(template, "{{" .. name .. "}}", res)
    end

    return template
end

-- performs templating using raw content and current buffer name
---@param template string
---@return string
function Templater:_process_for_current_buffer(template)
    return self:process {
        filename = vim.fn.expand "%:t",
        template = template,
    }
end

-- returns content of the template
---@param name string
---@return string?
function Templater:_get_raw_template_content(name)
    local templates = self:list_templates()
    for _, template in ipairs(templates) do
        if template:name() == name then
            return template:read()
        end
    end
    error(
        "Template with name "
            .. name
            .. " was not found in "
            .. vim.inspect(core.array_map(templates, function(x)
                return x:name()
            end))
    )
end

return Templater
