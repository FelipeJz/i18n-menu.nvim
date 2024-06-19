# i18n menu

This plugin simplifies the management of manual translations using i18n plugins.
Heavily inspired by i18n Ally

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
  end,
}

```

## Usage

- Requires [snippet-converter.nvim by smjonas](https://github.com/smjonas/snippet-converter.nvim)
- :TranslationMenu with cursor over the string

## TODO

- LSP missing translations
- Remove previous highlight
- Fix missing translations
