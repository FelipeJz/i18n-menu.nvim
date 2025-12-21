local api = vim.api
local fn = vim.fn
local M = {}
local ts = vim.treesitter
local json = require("snippet_converter.utils.json_utils")
local dig = require("i18n-menu.dig")
local json_util = require("i18n-menu.json_util")
local smart_default = require("i18n-menu.smart_default")

function M.load_translations(file)
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

function M.save_translations(file, translations)
  local order = json_util.keys_order(file)

  local f = io.open(file, "w")
  if f == nil then
    return false
  end
  local prettyContent = json:pretty_print(translations, order, true)
  f:write(prettyContent)
  f:close()
  return true
end

function M.get_project_root()
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

function M.read_config_file()
  local project_root = M.get_project_root()
  if not project_root then
    return nil
  end

  local config_path = project_root .. "/i18n.json"
  local file = io.open(config_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  if content == nil or content == "" then
    return nil
  end

  local config = vim.fn.json_decode(content)
  if config == nil then
    return nil
  end

  return config
end

function M.directory_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

function M.get_messages_dir()
  local config = M.read_config_file()
  local project_root = M.get_project_root()

  if not project_root then
    return {}
  end

  local messages_dir = config and config.messages_dir and project_root .. config.messages_dir or
      project_root .. "/messages"

  if not M.directory_exists(messages_dir) then
    return nil
  end

  return messages_dir
end

function M.get_translation_files()
  local messages_dir = M.get_messages_dir()
  if not messages_dir then
    return nil
  end
  local translation_files = fn.glob(messages_dir .. "/*.json", false, true)
  return translation_files
end

function M.iter_translation_keys(opts, callback)
  local bufnr = opts.bufnr
  local lang = opts.lang or "javascript"
  local function_name = opts.function_name or "t"

  local ok, parser = pcall(ts.get_parser, bufnr, lang)
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local root = tree:root()

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

  local ok_q, query = pcall(ts.query.parse, lang, query_string)
  if not ok_q then
    return
  end

  local start_row = opts.start_row or 0
  local end_row = opts.end_row or -1

  for id, node in query:iter_captures(root, bufnr, start_row, end_row) do
    if query.captures[id] == "translation_key" then
      callback(node)
    end
  end
end

function M.get_translation_key()
  local bufnr = api.nvim_get_current_buf()
  local config = M.read_config_file()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1

  local result

  M.iter_translation_keys({
    bufnr = bufnr,
    function_name = (config and config.function_name) or "t",
    start_row = row,
    end_row = row + 1,
  }, function(node)
    local sr, sc, er, ec = node:range()
    if row == sr and col >= sc and col <= ec then
      result = ts.get_node_text(node, bufnr)
    end
  end)

  return result
end

function M.highlight_group(is_present)
  local config = M.read_config_file()
  local present_highlight = dig.dig(config, "present_highlight") or "Comment"
  local missing_highlight = dig.dig(config, "missing_highlight") or "ErrorMsg"

  if is_present and present_highlight ~= "" then
    return present_highlight
  end

  if not is_present and missing_highlight ~= "" then
    return missing_highlight
  end

  return nil
end

function M.default_translation(translation_key)
  local config = M.read_config_file()
  local default_translation_strat = dig.dig(config, "default_translation")

  if default_translation_strat == "smart_default" then
    return smart_default.smart_default(translation_key)
  end

  return translation_key
end

return M
