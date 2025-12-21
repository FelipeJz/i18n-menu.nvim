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
  local buffer_number = api.nvim_get_current_buf()

  local translation_files = util.get_translation_files()
  if not translation_files then
    return
  end

  -- Clear previous hihgligts and diagnostics
  api.nvim_buf_clear_namespace(buffer_number, namespace, 0, -1)
  vim.diagnostic.reset(namespace, buffer_number)

  local ok_parser, parser = pcall(ts.get_parser, buffer_number, "javascript")
  if not ok_parser or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local root = tree:root()

  local function_name = (config and config.function_name) or "t"
  local query_string = string.format([[
    (call_expression
      function: (identifier) @func_name (#eq? @func_name "%s")
      arguments: (arguments
        (string
          (string_fragment) @translation_key
        )
      )
    )
  ]], function_name)

  local ok_query, query = pcall(ts.query.parse, "javascript", query_string)
  if not ok_query then
    return
  end

  local diagnostics = {}

  for capture_id, node in query:iter_captures(root, buffer_number, 0, -1) do
    if query.captures[capture_id] ~= "translation_key" then
      goto continue
    end

    local translation_key = ts.get_node_text(node, buffer_number)
    local start_row, start_col, end_row, end_col = node:range()

    local is_missing_translation = true
    for _, file_path in ipairs(translation_files) do
      local translations = util.load_translations(file_path)
      if dig.dig(translations, translation_key) then
        is_missing_translation = false
        break
      end
    end

    local highlight_group = util.highlight_group(is_missing_translation)
    if highlight_group then
      api.nvim_buf_set_extmark(
        buffer_number,
        namespace,
        start_row,
        start_col,
        {
          end_row = end_row,
          end_col = end_col,
          hl_group = highlight_group,
        }
      )
    end

    if is_missing_translation then
      table.insert(diagnostics, {
        bufnr = buffer_number,
        lnum = start_row,
        col = start_col,
        end_lnum = end_row,
        end_col = end_col,
        severity = vim.diagnostic.severity.WARN,
        source = "i18n-menu",
        message = "Translation missing: " .. translation_key,
      })
    end

    ::continue::
  end

  vim.diagnostic.set(namespace, buffer_number, diagnostics)
end

local function enter_translation(choice, translation_key, messages_dir)
  if not choice then return end

  local selected_language = choice.language
  local current_translation = choice.current_translation or ""
  local new_translation = vim.fn.input("Enter translation for '" ..
    translation_key .. "' in " .. selected_language .. ": ", current_translation)

  if new_translation ~= "" then
    local translation_file = messages_dir .. "/" .. selected_language .. ".json"
    local translations = util.load_translations(translation_file)
    dig.place(translations, translation_key, new_translation)
    util.save_translations(translation_file, translations)
    M.highlight_translation_references()
  end
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

  local config = util.read_config_file()
  local skip_lang_select = dig.dig(config, "skip_lang_select")
  local default_lang = dig.dig(config, "default_lang")

  for _, file in ipairs(translation_files) do
    local language = fn.fnamemodify(file, ":t:r")
    local translations = util.load_translations(file)
    local current_translation = dig.dig(translations, translation_key)
    local status = current_translation and current_translation or "------"

    local choice = {
      language = language,
      status = status,
      current_translation = current_translation
    }

    if skip_lang_select and language == default_lang then
      enter_translation(choice, translation_key, messages_dir)
      return
    end

    table.insert(items, choice)
  end

  vim.ui.select(items, {
    prompt = "Choose a language to add translation:",
    format_item = function(item)
      return ">> " .. item.language .. ": " .. item.status
    end,
  }, function(choice) enter_translation(choice, translation_key, messages_dir) end)
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
  local default_translation = util.default_translation(translation_key)

  dig.place(translations, translation_key, default_translation)

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
