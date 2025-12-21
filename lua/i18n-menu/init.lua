local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}
local util = require("i18n-menu.util")
local dig = require("i18n-menu.dig")

function M.highlight_translation_references()
  local config = util.read_config_file()
  local project_root = util.get_project_root()
  if not project_root then return end

  local bufnr = api.nvim_get_current_buf()
  local namespace = api.nvim_create_namespace("i18n-menu")

  local translation_files = util.get_translation_files()
  if not translation_files then return end

  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.diagnostic.reset(namespace, bufnr)

  local diagnostics = {}

  util.iter_translation_keys({
    bufnr = bufnr,
    function_name = (config and config.function_name) or "t",
  }, function(node)
    local key = ts.get_node_text(node, bufnr)
    local sr, sc, er, ec = node:range()

    local missing = true
    for _, file in ipairs(translation_files) do
      if dig.dig(util.load_translations(file), key) then
        missing = false
        break
      end
    end

    local hl = util.highlight_group(missing)
    if hl then
      api.nvim_buf_set_extmark(bufnr, namespace, sr, sc, {
        end_row = er,
        end_col = ec,
        hl_group = hl,
      })
    end

    if missing then
      diagnostics[#diagnostics + 1] = {
        bufnr = bufnr,
        lnum = sr,
        col = sc,
        end_lnum = er,
        end_col = ec,
        severity = vim.diagnostic.severity.WARN,
        source = "i18n-menu",
        message = "Translation missing: " .. key,
      }
    end
  end)

  vim.diagnostic.set(namespace, bufnr, diagnostics)
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
