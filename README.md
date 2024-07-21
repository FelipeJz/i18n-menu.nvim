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
    vim.keymap.set("n", "<leader>ii", ":TranslateMenu<cr>")
    vim.keymap.set("n", "<leader>id", ":TranslateDefault<cr>")
  end,
}

```

## Usage

- :TranslationMenu - Shows the translation menu.
- :TranslationDefault - Sets the key as the default translation, then shows the menu.

### Config file

i18n.json - This optional config file should be located in the project_root and allows you to change some variables at a project level.

```JSON
{
    "function_name": "t"
    "messages_dir": "/messages",
    "default_lang": "en"
}
```

## TODO

- Fix missing translations
- No dependecy JSON formatter
- Custom highlight colors
