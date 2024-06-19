local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}
local json = require("snippet_converter.utils.json_utils")

local function load_translations(file)
  local f = io.open(file, "r")
  if f == nil then
    return {}
  end

  local content = f:read("*all")
  f:close()

  if not content or content == "" then
    return {}
  end

  local success, translations = pcall(vim.fn.json_decode, content)
  if not success then
    return {}
  end

  if type(translations) ~= "table" then
    return {}
  end

  return translations
end

local function save_translations(file, translations)
  local f = io.open(file, "w")
  if f == nil then
    return false
  end
  local prettyContent = json:pretty_print(translations)
  f:write(prettyContent)
  f:close()
  return true
end

local function get_project_root()
  local current_file = api.nvim_buf_get_name(0)
  local current_dir = fn.fnamemodify(current_file, ":p:h")

  -- Define the markers to identify the project root
  local markers = { ".git", "package.json", "i18n.conf" }

  local function is_project_root(dir)
    for _, marker in ipairs(markers) do
      if fn.glob(dir .. "/" .. marker) ~= "" then
        return true
      end
    end
    return false
  end

  -- Search upwards from the current directory to find the project root
  -- Really, no better way of doing this?
  local project_root = current_dir
  while true do
    if is_project_root(project_root) then
      break
    end
    if project_root == "/" then
      project_root = nil
      break
    end
    project_root = fn.fnamemodify(project_root, ":h")
  end

  return project_root
end

local function read_config_file()
  local project_root = get_project_root()
  if not project_root then
    return nil
  end

  local config_file = project_root .. "/i18n.conf"
  local f = io.open(config_file, "r")
  if f == nil then
    return nil
  end

  local content = {}
  for line in f:lines() do
    for key, value in string.gmatch(line, "(%w+)%s*=%s*(%w+)") do
      content[key] = value
    end
  end
  f:close()
  return content
end

function M.get_translation_files()
  local project_root = get_project_root()

  if not project_root then
    return {}
  end

  local messages_dir = project_root .. "/messages/"
  local translation_files = fn.glob(messages_dir .. "*.json", false, true)

  return translation_files
end

local function read_translations()
  local config = read_config_file()
  local default_language = config and config.default_language or "en"
  local translation_file = get_project_root() .. "/messages/" .. default_language .. ".json"

  local translations = {}
  local data = load_translations(translation_file)
  for key, _ in pairs(data) do
    translations[key] = true
  end

  return translations
end

function M.highlight_translation_references()
  local project_root = get_project_root()
  if not project_root then
    return
  end

  local translation_files = M.get_translation_files()
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
      local translations = load_translations(file)
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

  local project_root = get_project_root()
  if not project_root then
    return
  end

  local messages_dir = project_root .. "/messages/"
  local translation_files = fn.glob(messages_dir .. "*.json", false, true)
  local items = {}

  for _, file in ipairs(translation_files) do
    local language = fn.fnamemodify(file, ":t:r")
    local translations = load_translations(file)
    local status = translations[translation_key] and "translated" or "no translation"
    table.insert(items, language .. " (" .. status .. ")")
  end

  vim.ui.select(items, {
    prompt = "Choose a language to add translation:",
    format_item = function(item)
      return ">> " .. item
    end,
  }, function(choice)
    if choice then
      local selected_language = choice:match("^(%w+)")
      local new_translation = vim.fn.input("Enter translation for '" ..
        translation_key .. "' in " .. selected_language .. ": ")

      local translation_file = messages_dir .. selected_language .. ".json"
      local translations = load_translations(translation_file)
      translations[translation_key] = new_translation
      save_translations(translation_file, translations)

      M.highlight_translation_references()
    end
  end)
end

function M.setup()
  api.nvim_command("augroup TranslateHighlight")
  api.nvim_command("autocmd!")
  api.nvim_command(
    "autocmd BufEnter,BufRead *.jsx,*.tsx lua require('i18n-menu').highlight_translation_references()")
  api.nvim_command(
    "autocmd TextChanged,TextChangedI *.jsx,*.tsx lua require('i18n-menu').highlight_translation_references()")
  api.nvim_command("augroup END")

  api.nvim_command("command! TranslateMenu lua require('i18n-menu').show_translation_menu()")
end

return M
