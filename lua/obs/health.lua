local EXPECTED_COMMANDS = {
    "ObsNvimTemplate",
    "ObsNvimRandomNote",
    "ObsNvimCopyObsidianLinkToNote",
    "ObsNvimCopyWikiLinkToNote",
    "ObsNvimOpenInObsidian",
    "ObsNvimFollowLink",
    "ObsNvimNextLink",
    "ObsNvimPrevLink",
    "ObsNvimNewNote",
    "ObsNvimDailyNote",
    "ObsNvimWeeklyNote",
    "ObsNvimBacklinks",
    "ObsNvimRename",
    "ObsNvimMove",
}

local TEMPLATE_DISPLAY_LIMIT = 20

local M = {}

local function ok(message)
    vim.health.ok(message)
end

local function warn(message, advice)
    vim.health.warn(message, advice)
end

local function error(message, advice)
    vim.health.error(message, advice)
end

local function info(message)
    vim.health.info(message)
end

---@param module_name string
---@param label string
---@return boolean, any
local function check_module(module_name, label)
    local loaded, module = pcall(require, module_name)
    if loaded then
        ok(label .. " is available")
        return true, module
    end

    error(label .. " is not available", module)
    return false, nil
end

---@param name string
---@param value any
local function check_function(name, value)
    if type(value) == "function" then
        ok(name .. " is available")
    else
        error(name .. " is not available")
    end
end

local function check_clipboard()
    if vim.fn.has "clipboard" == 1 then
        ok "Clipboard support is available"
    else
        warn(
            "Clipboard support is not available",
            "Install a clipboard provider to use ObsNvimCopyObsidianLinkToNote"
        )
    end
end

local function check_commands()
    local commands = vim.api.nvim_get_commands {}

    for _, command in ipairs(EXPECTED_COMMANDS) do
        if commands[command] then
            ok(":" .. command .. " is registered")
        else
            error(":" .. command .. " is not registered")
        end
    end
end

---@param path obs.utils.Path?
---@param label string
---@param missing_level "warn"|"error"
---@return boolean
local function check_directory(path, label, missing_level)
    if not path then
        error(label .. " is not configured")
        return false
    end

    local expanded = path:expand()
    if not path:exists() then
        if missing_level == "error" then
            error(label .. " does not exist: " .. expanded)
        else
            warn(label .. " does not exist: " .. expanded)
        end
        return false
    end

    if not path:is_dir() then
        error(label .. " is not a directory: " .. expanded)
        return false
    end

    ok(label .. " exists: " .. expanded)
    return true
end

---@param files obs.utils.File[]
---@return string[]
local function file_names(files)
    local names = {}
    for _, file in ipairs(files) do
        names[#names + 1] = file:name()
    end
    table.sort(names)
    return names
end

---@param names string[]
---@return table<string, boolean>
local function name_set(names)
    local result = {}
    for _, name in ipairs(names) do
        result[name] = true
    end
    return result
end

---@param names string[]
---@return string
local function format_limited_names(names)
    local visible_names = {}
    local limit = math.min(#names, TEMPLATE_DISPLAY_LIMIT)
    for i = 1, limit do
        visible_names[#visible_names + 1] = names[i]
    end

    local result = table.concat(visible_names, ", ")
    local remaining = #names - limit
    if remaining > 0 then
        result = result .. " (" .. remaining .. " more)"
    end
    return result
end

---@param template_names string[]
---@param template_name string?
---@param label string
local function check_configured_template(template_names, template_name, label)
    if not template_name then
        info(label .. " template is not configured")
        return
    end

    local templates = name_set(template_names)
    if templates[template_name] then
        ok(label .. " template is available: " .. template_name)
    else
        warn(label .. " template is missing: " .. template_name)
    end
end

---@param vault obs.Vault
local function check_vault(vault)
    info("Vault name: " .. tostring(vault._name))

    local vault_ready =
        check_directory(vault._home_path, "Vault directory", "error")
    if vault_ready then
        local notes = vault:list_notes()
        info("Markdown notes: " .. #notes)
    end

    local templater = vault._templater
    local template_names = {}
    if templater then
        local templates_ready =
            check_directory(templater._home_path, "Templates directory", "warn")
        if templates_ready then
            template_names = file_names(templater:list_templates())
            if #template_names == 0 then
                info "Templates: none found"
            else
                info("Templates: " .. format_limited_names(template_names))
            end
        end
    else
        warn "Templater is not configured"
    end

    local journal = vault._journal
    if journal then
        check_configured_template(
            template_names,
            journal._daily_template_name,
            "Daily"
        )
        check_configured_template(
            template_names,
            journal._weekly_template_name,
            "Weekly"
        )

        local journal_ready =
            check_directory(journal._home_path, "Journal directory", "warn")
        if journal_ready then
            info("Daily notes: " .. #journal:list_dailies())
            info("Weekly notes: " .. #journal:list_weeklies())
        end
    else
        warn "Journal is not configured"
    end
end

function M.check()
    vim.health.start "obs.nvim"

    local obs_loaded, obs = check_module("obs", "obs.nvim")

    check_function("vim.ui.select", vim.ui and vim.ui.select)
    check_function("vim.ui.open", vim.ui and vim.ui.open)
    check_function(
        "vim.api.nvim_create_user_command",
        vim.api.nvim_create_user_command
    )
    check_clipboard()
    check_commands()

    if not obs_loaded then
        return
    end

    if not obs.vault then
        warn(
            "obs.setup() has not been called",
            "Call require('obs').setup({ vault_home = ... }) from your config"
        )
        return
    end

    ok "obs.setup() has been called"
    check_vault(obs.vault)
end

return M
