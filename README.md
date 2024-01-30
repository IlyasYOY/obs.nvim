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
        dev = true,
        config = function()
            local obs = require "obs"

            obs.setup {
                vault_home = "~/Notes",
                vault_name = "Notes",
                journal = {
                    template_name = "daily",
                },
            }

            vim.keymap.set("n", "<leader>nn", "<cmd>ObsNvimFollowLink<cr>")
            vim.keymap.set("n", "<leader>nr", "<cmd>ObsNvimRandomNote<cr>")
            vim.keymap.set("n", "<leader>nN", "<cmd>ObsNvimNewNote<cr>")
            vim.keymap.set("n", "<leader>ny", "<cmd>ObsNvimCopyObsidianLinkToNote<cr>")
            vim.keymap.set("n", "<leader>no", "<cmd>ObsNvimOpenInObsidian<cr>")
            vim.keymap.set("n", "<leader>nd", "<cmd>ObsNvimDailyNote<cr>")
            vim.keymap.set("n", "<leader>nw", "<cmd>ObsNvimWeeklyNote<cr>")
            vim.keymap.set("n", "<leader>nrn", "<cmd>ObsNvimRename<cr>")
            vim.keymap.set("n", "<leader>nT", "<cmd>ObsNvimTemplate<cr>")
            vim.keymap.set("n", "<leader>nM", "<cmd>ObsNvimMove<cr>")
            vim.keymap.set("n", "<leader>nb", "<cmd>ObsNvimBacklinks<cr>")
            vim.keymap.set("n", "<leader>nfj", "<cmd>ObsNvimFindInJournal<cr>")
            vim.keymap.set("n", "<leader>nff", "<cmd>ObsNvimFindNote<cr>")
            vim.keymap.set("n", "<leader>nfg", "<cmd>ObsNvimFindInNotes<cr>")
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

- *Insert template using telescope.* `:ObsNvimTemplate` opens dialog with `<CR>` mapped to insert template in the line below. 
- *Follow link under cursor.* `:ObsNvimFollowLink`.
- *Open random note.* `:ObsNvimRandomNote`.
- *Copy obsidian link to a current note.* `:ObsNvimCopyObsidianLinkToNote`.
- *Open obsidian link to a current note.* `:ObsNvimOpenInObsidian`. If you don't have `Browse` command then you can create it manually like [so](https://github.com/IlyasYOY/dotfiles/blob/04f4a5772937792e63f1b38b51730109cc0c35ca/config/nvim/lua/ilyasyoy/init.lua#L13-L32).
- *Creates a new note.* `:ObsNvimNewNote` prefixes note with `YYYY-MM-dd`. In case of empty name plugin generates name from time-stamp. Example: `2023-03-12 1678625141.md`.
- *Opens daily note.* `:ObsNvimDailyNote` creates one if doesn't exist. 
- *Opens weekly note.* `:ObsNvimWeeklyNote` creates one if doesn't exist. 
- *Telescope find notes.* `:ObsNvimFindNote`.
- *Telescope find journal notes.* `:ObsNvimFindInJournal`.
- *Telescope live-grep through notes.* `:ObsNvimFinInNotes`.
- *Telescope through back-links.* `:ObsNvimBacklinks`.
- *Renames current note.* `:ObsNvimRename` updates links to the note. I advice you to rename notes inside **Obsidian** for important notes with lots of back-links. 
- *Move note to directory from search.* `:ObsNvimMove` launches telescope to find directory to move current note to.
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

- [Here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/snippets/markdown.lua) you can find useful **LuaSnip** snippets for **Obsidian**.
