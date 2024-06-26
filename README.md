# i18n menu

This plugin simplifies the management of manual translations using react i18n extensions.
Work in progress. Only tested in next-intl. Heavily inspired by i18n Ally.

## Installation

Using Lazy

```lua
{
  "felipejz/i18n-menu.nvim",
  dependencies = {
    "smjonas/snippet-converter.nvim",
  },
  config = function()
    require("i18n-menu").setup()
    vim.keymap.set("n", "<leader>i", ":TranslateMenu<cr>")
  end,
}

```

## Usage

- Requires [snippet-converter.nvim by smjonas](https://github.com/smjonas/snippet-converter.nvim)
- :TranslationMenu with cursor over the string

### Config file

i18n.json - This optional config file should be located in the project_root and allows you to change some variables at a project level.

```JSON
{
    "function_name": "t"
    "messages_dir": "/messages"
}
```

## TODO

- Fix missing translations
- No dependecy JSON formatter
- Custom highlight colors
