# i18n menu

This plugin provides an interactive Neovim menu for resolving and managing translation keys referenced by i18n translation functions. It highlights translatable strings passed to translation functions and reports diagnostics for missing or unresolved translations, streamlining manual internationalization workflows in React projects through integration with common i18n extension patterns. Currently a work in progress, tested with next-intl, and heavily inspired by i18n Ally.

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
    "function_name": "t",
    "messages_dir": "/messages",
    "default_lang": "en",
    "skip_lang_select": false

}
```

## TODO
- Auto translate using external libraries
- No dependecy JSON formatter
