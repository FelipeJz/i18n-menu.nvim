local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}
local util = require("i18n-menu.util")
local dig = require("i18n-menu.dig")

function M.highlight_translation_references()
  local config = util.read_config_file()
  local project_root = util.get_project_root()
  if not project_root then
    return
  end

  local namespace = api.nvim_create_namespace("i18n-menu")
  local bufnr = api.nvim_get_current_buf()

  local translation_files = util.get_translation_files()
  if not translation_files then
    return
  end

  -- Clear previous highlights
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  -- Clear diagnostics
  vim.diagnostic.reset(namespace, bufnr)

  local parser = ts.get_parser(bufnr, 'javascript')
  local tree = parser:parse()[1]
  local root = tree:root()

  local function_name = config and config.function_name or "t"
  local query = ts.query.parse('javascript', string.format([[
        (call_expression
            function: (identifier) @func_name (#eq? @func_name "%s")
            arguments: (arguments
                (string
                    (string_fragment) @translation_key
                )
            )
        )
    ]], function_name))

  local diagnostics = {}

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local translation_key_node = match[#match]
    local translation_key = ts.get_node_text(translation_key_node, bufnr)

    local is_missing_translation = true

    for _, file in ipairs(translation_files) do
      local translations = util.load_translations(file)
      if dig.dig(translations, translation_key) then
        break
      end
      is_missing_translation = false
    end

    local start_row, start_col, end_row, end_col = translation_key_node:range()

    local hl_group = util.highlight_group(is_missing_translation)
    if hl_group then
      api.nvim_buf_add_highlight(bufnr, -1, hl_group, start_row, start_col, end_col)
    end

    if not is_missing_translation then
      table.insert(diagnostics, {
        bufnr = bufnr,
        lnum = start_row,
        col = start_col,
        end_lnum = end_row,
        end_col = end_col,
        severity = vim.diagnostic.severity.WARN,
        source = "i18n-menu",
        message = "Translation missing: " .. translation_key,
      })
    end
  end
  -- Set diagnostics
  vim.diagnostic.set(namespace, bufnr, diagnostics)
end

function M.show_translation_menu()
  local translation_key = util.get_translation_key()
  if not translation_key then
    return
  end

  local project_root = util.get_project_root()
  if not project_root then
    return
  end

  local messages_dir = util.get_messages_dir()
  local translation_files = util.get_translation_files()
  if not translation_files or not messages_dir then
    return
  end

  local items = {}

  for _, file in ipairs(translation_files) do
    local language = fn.fnamemodify(file, ":t:r")
    local translations = util.load_translations(file)
    local current_translation = translations[translation_key]
    local status = current_translation and current_translation or "------"
    table.insert(items, {
      language = language,
      status = status,
      current_translation = current_translation
    })
  end

  vim.ui.select(items, {
    prompt = "Choose a language to add translation:",
    format_item = function(item)
      return ">> " .. item.language .. ": " .. item.status
    end,
  }, function(choice)
    if choice then
      local selected_language = choice.language
      local current_translation = choice.current_translation or ""
      local new_translation = vim.fn.input("Enter translation for '" ..
        translation_key .. "' in " .. selected_language .. ": ", current_translation)

      if new_translation ~= "" then
        local translation_file = messages_dir .. "/" .. selected_language .. ".json"
        local translations = util.load_translations(translation_file)
        translations[translation_key] = new_translation
        util.save_translations(translation_file, translations)
        M.highlight_translation_references()
      end
    end
  end)
end

function M.translate_default()
  local config = util.read_config_file()

  local translation_key = util.get_translation_key()
  if not translation_key then
    return
  end

  local project_root = util.get_project_root()
  if not project_root then
    return
  end

  local messages_dir = util.get_messages_dir()
  local translation_files = util.get_translation_files()
  if not translation_files or not messages_dir then
    return
  end

  local default_lang = "en"
  if config ~= nil then
    if config.default_lang then
      default_lang = config.default_lang
    end
  end

  local translation_file = messages_dir .. "/" .. default_lang .. ".json"
  local translations = util.load_translations(translation_file)
  translations[translation_key] = translation_key
  util.save_translations(translation_file, translations)
  M.highlight_translation_references()
  M.show_translation_menu()
end

function M.setup()
  api.nvim_command("augroup TranslateHighlight")
  api.nvim_command("autocmd!")
  api.nvim_command(
    "autocmd BufEnter,BufRead *.jsx,*.tsx lua require('i18n-menu').highlight_translation_references()")
  api.nvim_command(
    "autocmd InsertLeave *.jsx,*.tsx lua require('i18n-menu').highlight_translation_references()")
  api.nvim_command("augroup END")

  api.nvim_command("command! TranslateMenu lua require('i18n-menu').show_translation_menu()")
  api.nvim_command("command! TranslateDefault lua require('i18n-menu').translate_default()")
end

return M
