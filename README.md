# obs.nvim

`obs.nvim` is a WIP Neovim plugin for Obsidian-like Markdown notes.

It is built around a local note vault and small Neovim commands for common
note workflows:

- write notes without leaving Neovim
- follow `[[wiki links]]`
- create daily and weekly journal notes
- insert Markdown templates
- rename, move, and inspect backlinks for notes
- copy wiki or Obsidian links for the current note

## Installation

Example installation with [folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
    {
        "IlyasYOY/obs.nvim",
        config = function()
            local obs = require "obs"

            obs.setup {
                vault_home = "~/Notes",
                vault_name = "Notes",
                journal = {
                    daily_template_name = "daily",
                    weekly_template_name = "weekly",
                },
                templater = {
                    home = "~/Notes/meta/templates",
                    extra_providers = {
                        {
                            name = "descr",
                            func = function()
                                return vim.fn.input "Enter description: "
                            end,
                        },
                    },
                },
            }

            vim.keymap.set("n", "<leader>nn", "<cmd>ObsNvimFollowLink<cr>")
            vim.keymap.set("n", "<leader>nr", "<cmd>ObsNvimRandomNote<cr>")
            vim.keymap.set("n", "<leader>nN", "<cmd>ObsNvimNewNote<cr>")
            vim.keymap.set("n", "<leader>ny", "<cmd>ObsNvimCopyObsidianLinkToNote<cr>")
            vim.keymap.set("n", "<leader>nY", "<cmd>ObsNvimCopyWikiLinkToNote<cr>")
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

My configuration is
[here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/after/plugin/obs.lua).

`obs.setup()` accepts `obs.VaultOpts`, defined in
[`lua/obs/vault.lua`](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/vault.lua).

The most useful defaults are:

- `vault_home = "~/vimwiki"`
- `vault_name = "vimwiki"`
- `templater.home = "<vault_home>/meta/templates"`
- `journal.home = "<vault_home>/diary"`
- `journal.date_glob = "????-??-??"`
- `journal.week_glob = "????-W??"`

Daily notes use `journal.daily_template_name`. Weekly notes use
`journal.weekly_template_name`. The older `journal.template_name` option still
works as a deprecated alias for the daily template.

Wiki link completion requires Neovim 0.12 or newer and is enabled by default
for Markdown notes inside the vault. It completes note names inside `[[...]]`
with Neovim's built-in completion:

- use `CTRL-X CTRL-U` to trigger it manually
- set `vim.opt.autocomplete = true` in your config for Neovim's built-in
  automatic popup
- set `completion = { enabled = false }` in `obs.setup()` to disable it

Templates are Markdown files in `templater.home`. The default template variables
are:

| Variable | Value |
| --- | --- |
| `{{date}}` | Current date as `YYYY-MM-DD` |
| `{{title}}` | Current buffer filename without `.md` |

You can add custom variables with `templater.extra_providers`.

## Commands

| Command | Description |
| --- | --- |
| `:ObsNvimTemplate` | Select and insert a template into the current note. |
| `:ObsNvimFollowLink` | Follow the `[[wiki link]]` under the cursor. |
| `:ObsNvimRandomNote` | Open a random note from the vault. |
| `:ObsNvimNewNote` | Create a note prefixed with `YYYY-MM-DD-`; empty names use the current timestamp. |
| `:ObsNvimDailyNote[!] [date]` | Open a daily note, creating it if needed. Supports `YYYY-MM-DD`, `today`, `tomorrow`, `yesterday`, `N days ago`, and `in N days`; no argument opens today. Prefix with a count, such as `:10ObsNvimDailyNote`, or pass a number, such as `:ObsNvimDailyNote 10`, to open today + N days. Add `!` to choose the date from a calendar popup. Tab completes existing daily dates. |
| `:ObsNvimWeeklyNote` | Open this week's weekly note, creating it if needed. |
| `:ObsNvimBacklinks` | Select from notes that link to the current note. |
| `:ObsNvimRename` | Rename the current note and update matching wiki links. |
| `:ObsNvimMove` | Select a vault directory and move the current note there. |
| `:ObsNvimCopyObsidianLinkToNote` | Copy an Obsidian URL for the current note. |
| `:ObsNvimCopyWikiLinkToNote` | Copy a `[[wiki link]]` for the current note. |
| `:ObsNvimOpenInObsidian` | Open the current note in Obsidian. |

Most commands that act on the current buffer require the file to be a Markdown
note inside the configured vault.

Normal-mode mappings like `<cmd>ObsNvimDailyNote<cr>` do not automatically pass
`vim.v.count`. Use a function mapping if you want `10<leader>nd` to call
`:10ObsNvimDailyNote`. Using both a count and date text shows a warning and
does nothing.

The daily-note calendar popup shows one month at a time with ISO week numbers.
Existing daily notes are marked with `*` on day cells, and existing weekly notes
are marked with `*` next to the week number. Use `h`/`l` for previous/next day,
`k`/`j` for previous/next week, `K`/`J` for previous/next month, `<CR>` to open
the selected date, `w` to open the selected row's weekly note, `q` or `<Esc>` to
close, and `?` to toggle mapping help.

## Tips

- Useful LuaSnip snippets for Obsidian are
  [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/snippets/markdown.lua).
