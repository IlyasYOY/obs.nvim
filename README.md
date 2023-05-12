# obs.nvim 

Simple **NeoVim** plugin with Obsidian-like-notes support.

Why is it better than Obsidian: 

- Making **notes inside NeoVim** during coding sessions.
- **Lua** as extension language.
- Existing **NeoVim infrastructure**.

## Status 

Project is currently in WIP status.

## Installation

This project requires: 

- [IlyasYOY/coredor.nvim: Core utils for nvim](https://github.com/IlyasYOY/coredor.nvim). Utility library I use for my plugins.
- [nvim-lua/plenary.nvim: plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.](https://github.com/nvim-lua/plenary.nvim). Collection of useful utilities: testing, IO, etc.
- [nvim-telescope/telescope.nvim: Find, Filter, Preview, Pick. All lua, all the time.](https://github.com/nvim-telescope/telescope.nvim). Fuzzy-searching.

Plugin provides a [source](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/cmp-source.lua) for completion using [hrsh7th/nvim-cmp: A completion plugin for neovim coded in Lua.](https://github.com/hrsh7th/nvim-cmp).

Example installation using [folke/lazy.nvim](https://github.com/folke/lazy.nvim): 

```lua
return {
    {
        "IlyasYOY/obs.nvim",
        dependencies = {
            "IlyasYOY/coredor.nvim",
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = function()
            local obs = require "obs"
            obs.setup {
                -- Settings for your vault...
            }
            -- Your setup logic goes here...
        end,
    },
}
```

## Configuration

My configuration you can find [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/lua/plugins/obs.lua). 

### setup 

Example `setup`:

```lua 
obs.setup {
    journal = {
        -- setting for daily template note name
        template_name = "daily",
    },
}
```

Type definition for table is provided [here](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/vault.lua) as `obs.VaultOpts`.

I won't go over all configuration options in details. There are the most important defaults the plugin provides: 

- `~/vimwiki` as directory for notes, with sub-directories:
    - `./meta/templates` as templates folder.
    - `./diary` as daily notes folder.

### mappings 

Example mappings configuration may be found [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/lua/plugins/obs.lua).  

- *Insert template using telescope.* Function opens dialog with `<CR>` mapped to insert template in the line below. 

```lua
vim.keymap.set("n", "<leader>nT", function()
    obs.vault:run_if_note(function()
        obs.vault:find_and_insert_template()
    end)
end, { desc = "Inserts notes Template" })
```

- *Follow link under cursor.*

```lua
vim.keymap.set("n", "<leader>nn", function()
    obs.vault:run_if_note(function()
        obs.vault:follow_link()
    end)
end, { desc = "navigate to note" })
```

- *Creates a new note.* This function prefixes note with `YYYY-MM-dd`. In case of empty name plugin generates name from time-stamp. Example: `2023-03-12 1678625141.md`.

```lua
vim.keymap.set("n", "<leader>nN", function()
    local input = vim.fn.input {
        prompt = "New note name: ",
        default = "",
    }
    local file = obs.vault:create_note(input)
    if file then
        file:edit()
    else
        vim.notify("Note '" .. input .. "' already exists")
    end
end, { desc = "create new Note" })
```

- *Opens daily note.* Creates one if doesn't exist. 

```lua
vim.keymap.set("n", "<leader>nd", function()
    obs.vault:open_daily()
end, { desc = "notes daily" })
```

- *Telescope find notes.*

```lua
vim.keymap.set("n", "<leader>nff", function()
    obs.vault:find_note()
end, { desc = "notes files find" })
```

- *Telescope find journal notes.*

```lua
vim.keymap.set("n", "<leader>nfj", function()
    obs.vault:find_journal()
end, { desc = "notes find journal" })
```

- *Telescope live-grep through notes.*

```lua
vim.keymap.set("n", "<leader>nfg", function()
    obs.vault:grep_note()
end, { desc = "notes files grep" })
```

- *Telescope through back-links.*

```lua
vim.keymap.set("n", "<leader>nfb", function()
    obs.vault:run_if_note(function()
        obs.vault:find_current_note_backlinks()
    end)
end, { desc = "notes find back-links" })
```

- *Renames current note.* This function updates links to the note. I advice you to rename notes inside **Obsidian** for important notes with lots of back-links.

```lua
vim.keymap.set("n", "<leader>nrn", function()
    obs.vault:rename_current_note()
end, { desc = "notes rename current" })
```

- *Move note to directory from search.* Function launches telescope to find directory to move current note to.

```lua
vim.keymap.set("n", "<leader>nM", function()
    obs.vault:run_if_note(function()
        obs.vault:find_directory_and_move_current_note()
    end)
end, { desc = "move notes to directory" })
```

- *Setup nvim-cmp completion source.* After that you'll be able to use completion for notes inside your vault.

```lua
-- config for nvim-cmp
local cmp_source = require "obs.cmp-source"
cmp.register_source("obs", cmp_source.new())

-- config for obs.nvim
local group = vim.api.nvim_create_augroup(
    "ObsNvim",
    { clear = true }
)

vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = "*.md",
    desc = "Setup notes nvim-cmp source",
    callback = function()
        if obs.vault:is_current_buffer_in_vault() then
            require("cmp").setup.buffer {
                sources = {
                    { name = "obs" },
                    { name = "luasnip" },
                },
            }
        end
    end,
})
```

## Tips 

- [Here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/snippets/markdown.lua) you van find useful **LuaSnip** snippets for **Obsidian**.
