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

- [nvim-lua/plenary.nvim: plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.](https://github.com/nvim-lua/plenary.nvim). Collection of useful utilities: testing, IO, etc.


Plugin provides a [source](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/cmp-source.lua) for completion using [hrsh7th/nvim-cmp: A completion plugin for neovim coded in Lua.](https://github.com/hrsh7th/nvim-cmp).

Example installation using [folke/lazy.nvim](https://github.com/folke/lazy.nvim): 

```lua
return {
    {
        "IlyasYOY/obs.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
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

        end,
    },
}
```

## Configuration

My configuration you can find [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/lua/plugins/obs-nvim.lua).

### setup 

Example `setup`:

```lua 
obs.setup {
    journal = {
        -- setting for daily note template name
        daily_template_name = "daily",
    },
}
```

Type definition for table is provided [here](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/vault.lua) as `obs.VaultOpts`.

I won't go over all configuration options in details. There are the most important defaults the plugin provides: 

- `~/vimwiki` as directory for notes, with sub-directories:
    - `./meta/templates` as templates folder.
    - `./diary` as daily notes folder.

### mappings 

Example mappings configuration may be found [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/lua/plugins/obs-nvim.lua).

- *Insert template.* `:ObsNvimTemplate` opens dialog to select and insert template. 
- *Follow link under cursor.* `:ObsNvimFollowLink`.
- *Open random note.* `:ObsNvimRandomNote`.
- *Copy obsidian link to a current note.* `:ObsNvimCopyObsidianLinkToNote`.
- *Open obsidian link to a current note.* `:ObsNvimOpenInObsidian`. If you don't have `Browse` command then you can create it manually like [so](https://github.com/IlyasYOY/dotfiles/blob/04f4a5772937792e63f1b38b51730109cc0c35ca/config/nvim/lua/ilyasyoy/init.lua#L13-L32).
- *Creates a new note.* `:ObsNvimNewNote` prefixes note with `YYYY-MM-dd`. In case of empty name plugin generates name from time-stamp. Example: `2023-03-12 1678625141.md`.
- *Opens daily note.* `:ObsNvimDailyNote` creates one if doesn't exist. 
- *Opens weekly note.* `:ObsNvimWeeklyNote` creates one if doesn't exist. 
- *Find backlinks.* `:ObsNvimBacklinks`.
- *Renames current note.* `:ObsNvimRename` updates links to the note. I advice you to rename notes inside **Obsidian** for important notes with lots of back-links. 
- *Move note to directory.* `:ObsNvimMove` opens dialog to select directory to move current note to.

## Tips 

- [Here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/snippets/markdown.lua) you can find useful **LuaSnip** snippets for **Obsidian**.
