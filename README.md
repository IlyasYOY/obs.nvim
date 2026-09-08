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

## Requirements

- Neovim 0.11 or newer
- a clipboard provider for link-copy commands
- Neovim 0.12 or newer for built-in wiki-link completion

## Installation

Neovim 0.11 users should install the plugin with lazy.nvim or another plugin
manager. Neovim's built-in `vim.pack` requires Neovim 0.12 or newer.

Example installation with [folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
    {
        "IlyasYOY/obs.nvim",
    },
}
```

Example installation with Neovim 0.12+'s built-in `vim.pack`:

```lua
vim.pack.add {
    { src = "https://github.com/IlyasYOY/obs.nvim" },
}
```

## Health

After setup, run:

```vim
:checkhealth obs
```

The health check verifies that the plugin loads, `obs.setup()` has run, expected
commands are registered, the required Neovim APIs and clipboard support are
available, and the configured vault, templates, journal directories, and note,
daily, or weekly templates are visible.

## Configuration

My configuration is
[here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/after/plugin/obs.lua).

Example configuration:

```lua
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
        note_template_name = "note",
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
vim.keymap.set("n", "<leader>nt", "<cmd>ObsNvimTags<cr>")
vim.keymap.set("n", "<leader>ng", "<cmd>ObsNvimTag<cr>")
vim.keymap.set("n", "]l", function()
    vim.cmd(vim.v.count1 .. "ObsNvimNextLink")
end)
vim.keymap.set("n", "[l", function()
    vim.cmd(vim.v.count1 .. "ObsNvimPrevLink")
end)
```

`obs.setup()` accepts `obs.VaultOpts`, defined in
[`lua/obs/vault.lua`](https://github.com/IlyasYOY/obs.nvim/blob/main/lua/obs/vault.lua).

The most useful options are:

| Option | Default | Description |
| --- | --- | --- |
| `vault_home` | `~/vimwiki` | Root directory for Markdown notes. |
| `vault_name` | `vimwiki` | Obsidian vault name used when building `obsidian://` links. |
| `templater.home` | `<vault_home>/meta/templates` | Directory containing Markdown templates. |
| `templater.include_default_providers` | `true` | Enables the built-in `{{date}}` and `{{title}}` template variables. |
| `templater.note_template_name` | `nil` | Template name used when creating regular notes with `:ObsNvimNewNote`. |
| `templater.extra_providers` | `{}` | Adds custom template variables. |
| `journal.home` | `<vault_home>/diary` | Directory for daily and weekly journal notes. |
| `journal.daily_template_name` | `nil` | Template name used when creating daily notes. |
| `journal.weekly_template_name` | `nil` | Template name used when creating weekly notes. |
| `journal.date_glob` | `????-??-??` | Glob used to list daily journal notes. |
| `journal.week_glob` | `????-W??` | Glob used to list weekly journal notes. |
| `completion.enabled` | `true` on Neovim 0.12+ | Enables built-in wiki link completion for Markdown notes inside the vault. |
| `completion.fuzzy` | `false` | Uses fuzzy matching and relevance ordering for note suggestions only. |

Regular notes created with `:ObsNvimNewNote` use
`templater.note_template_name`. Daily notes use `journal.daily_template_name`.
Weekly notes use `journal.weekly_template_name`. The older
`journal.template_name` option still works as a deprecated alias for the daily
template.

Wiki link completion requires Neovim 0.12 or newer and is enabled by default
for Markdown notes inside the vault. It completes note names inside `[[...]]`
with Neovim's built-in completion. Inside an existing link, candidates are
bare note names. Completing a candidate replaces the entire note name,
including text to the right of the cursor, while preserving the closing
`]]` and any `|alias` or `#heading`. For an incomplete
link without that boundary, the closing `]]` is added as before.

- use `CTRL-X CTRL-U` to trigger it manually
- set `vim.opt.autocomplete = true` in your config for Neovim's built-in
  automatic popup
- set `completion = { enabled = false }` in `obs.setup()` to disable it

Set `completion = { fuzzy = true }` in `obs.setup()` to match nonconsecutive
characters in note names (for example, `[[apl` matches `apple`). This uses
Neovim's built-in fuzzy scoring; an empty query lists notes alphabetically.
By default, matching is case-insensitive by prefix. Fuzzy note completion
does not change `completeopt` or the matching behavior of other sources.

Templates are Markdown files in `templater.home`. The default template variables
are:

| Variable | Value |
| --- | --- |
| `{{date}}` | Current date as `YYYY-MM-DD` |
| `{{title}}` | Current buffer filename without `.md` |

You can add custom variables with `templater.extra_providers`, or set
`templater.include_default_providers = false` to disable the built-in variables.

## Commands

| Command | Description |
| --- | --- |
| `:ObsNvimTemplate` | Select and insert a template into the current note. |
| `:ObsNvimFollowLink` | Follow the `[[wiki link]]` under the cursor. |
| `:ObsNvimNextLink[!]` | Move to the next link in the current note. By default only `[[wiki links]]` are used; add `!` to include inline Markdown links and bare HTTP/HTTPS links. Prefix a count, such as `:3ObsNvimNextLink`, to move multiple links forward. |
| `:ObsNvimPrevLink[!]` | Move to the previous link in the current note. Prefix a count, such as `:3ObsNvimPrevLink`, to move multiple links backward. |
| `:ObsNvimRandomNote` | Open a random note from the vault. |
| `:ObsNvimNewNote` | Create a note prefixed with `YYYY-MM-DD-`; empty names use the current timestamp. Expands `templater.note_template_name` when configured. |
| `:ObsNvimDailyNote[!] [date]` | Open a daily note, creating it if needed. Supports `YYYY-MM-DD`, `today`, `tomorrow`, `yesterday`, `N days ago`, and `in N days`; no argument opens today. Prefix with a count, such as `:10ObsNvimDailyNote`, or pass a number, such as `:ObsNvimDailyNote 10`, to open today + N days. Add `!` to choose the date from a calendar popup; with `!`, relative inputs and counts step from the current buffer's date when it is a daily note (otherwise today). Tab completes existing daily dates. |
| `:ObsNvimWeeklyNote` | Open this week's weekly note, creating it if needed. |
| `:ObsNvimBacklinks` | Select from notes that link to the current note. |
| `:ObsNvimTags` | Select a vault tag, then select and open a note with that tag. |
| `:ObsNvimTag [tag]` | Select and open a note with the provided tag, or the tag under the cursor. |
| `:ObsNvimRename` | Rename the current note and update matching wiki links on disk and in loaded buffers. The current buffer stays open with its unsaved edits and is associated with the new path; write it explicitly to save. Unsaved edits in other affected buffers remain unsaved, while clean buffers stay clean. If an affected buffer is nonmodifiable, or the destination is already open in another buffer, the rename is rejected before changing files or links. |
| `:ObsNvimMove` | Select a vault directory and move the current note there. If a note with the same name already exists in the destination, the move is rejected with a notification and the source is preserved. |
| `:ObsNvimCopyObsidianLinkToNote` | Copy an Obsidian URL for the current note. |
| `:ObsNvimCopyWikiLinkToNote` | Copy a `[[wiki link]]` for the current note. |
| `:ObsNvimOpenInObsidian` | Open the current note in Obsidian. |

Most commands that act on the current buffer require the file to be a Markdown
note inside the configured vault.

`:ObsNvimNextLink` wraps at file boundaries. The example `]l` and `[l` mappings
preserve counts, so `3]l` moves three wiki links forward and `2[l` moves two
wiki links backward. Use `:ObsNvimNextLink!` or `:ObsNvimPrevLink!` when you
want Markdown links like `[label](target.md)` and bare links like
`https://example.com` included too.

Normal-mode mappings like `<cmd>ObsNvimDailyNote<cr>` do not automatically pass
`vim.v.count`. Use a function mapping if you want `10<leader>nd` to call
`:10ObsNvimDailyNote`. Using both a count and date text shows a warning and
does nothing.

The daily-note calendar popup shows one month at a time with ISO week numbers.
When opened from a daily note (`YYYY-MM-DD.md` in the journal home), the
calendar and any relative input — `today`, `tomorrow`, `yesterday`,
`in N days`, `N days ago`, or a count — anchor on that note's date; explicit
`YYYY-MM-DD` dates stay absolute. From any other buffer it opens on today.
Existing daily notes are marked with `*` on day cells, and existing weekly notes
are marked with `*` next to the week number. Use `h`/`l` for previous/next day,
`k`/`j` for previous/next week, `K`/`J` for previous/next month, `<CR>` to open
the selected date, `w` to open the selected row's weekly note, `q` or `<Esc>` to
close, and `?` to toggle mapping help.

## Tips

- Useful LuaSnip snippets for Obsidian are
  [here](https://github.com/IlyasYOY/dotfiles/blob/master/config/nvim/snippets/markdown.lua).

Vim help is available with `:help obs.nvim`.

## Development

Run `make check` for the canonical non-mutating lint, test, and Vim-help
verification. Use `make test NVIM_VERSION=v0.11.7` and
`make test NVIM_VERSION=v0.12.5` for the supported release lines; nightly is
an additional compatibility probe.

## License

Apache-2.0. See [LICENSE](LICENSE).
