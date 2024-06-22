local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}
local util = require("i18n-menu.util")

function M.highlight_translation_references()
  local project_root = util.get_project_root()
  if not project_root then
    return
  end

  local translation_files = util.get_translation_files()
  local bufnr = api.nvim_get_current_buf()

  -- Clear previous highlights
  api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  local parser = ts.get_parser(bufnr, 'javascript')
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = ts.query.parse('javascript', [[
        (call_expression
            function: (identifier) @func_name (#eq? @func_name "t")
            arguments: (arguments
                (string
                    (string_fragment) @translation_key
                )
            )
        )
    ]])

  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local translation_key_node = match[#match]
    local translation_key = ts.get_node_text(translation_key_node, bufnr)

    local is_missing_translation = true

    for _, file in ipairs(translation_files) do
      local translations = util.load_translations(file)
      if translations[translation_key] then
        break
      end
      is_missing_translation = false
    end

    local hl_group = is_missing_translation and "Comment" or "ErrorMsg"
    local start_row, start_col, end_row, end_col = translation_key_node:range()
    api.nvim_buf_add_highlight(bufnr, -1, hl_group, start_row, start_col, end_col)
  end
end

function M.show_translation_menu()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local parser = ts.get_parser(bufnr, 'javascript')
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = ts.query.parse('javascript', [[
        (call_expression
            function: (identifier) @func_name (#eq? @func_name "t")
            arguments: (arguments
                (string
                    (string_fragment) @translation_key
                )
            )
        )
    ]])

  local translation_key
  for _, match in query:iter_matches(root, bufnr, row, row + 1) do
    local translation_key_node = match[#match]
    local start_row, start_col, end_row, end_col = translation_key_node:range()
    if row == start_row and col >= start_col and col <= end_col then
      translation_key = ts.get_node_text(translation_key_node, bufnr)
      break
    end
  end

  if not translation_key then
    return
  end

  local project_root = util.get_project_root()
  if not project_root then
    return
  end

  local messages_dir = project_root .. "/messages/"
  local translation_files = fn.glob(messages_dir .. "*.json", false, true)
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
        local translation_file = messages_dir .. selected_language .. ".json"
        local translations = util.load_translations(translation_file)
        translations[translation_key] = new_translation
        util.save_translations(translation_file, translations)
        M.highlight_translation_references()
      end
    end
  end)
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
end

return M
