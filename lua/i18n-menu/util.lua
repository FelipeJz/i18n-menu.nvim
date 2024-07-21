local api = vim.api
local fn = vim.fn
local M = {}
local ts = vim.treesitter
local json = require("snippet_converter.utils.json_utils")

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
  local f = io.open(file, "w")
  if f == nil then
    return false
  end
  local prettyContent = json:pretty_print(translations)
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
    print("Error: i18n-menu: Messages directory not found")
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

function M.get_translation_key()
  local bufnr = api.nvim_get_current_buf()
  local config = M.read_config_file()
  local cursor = api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

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

  local translation_key
  for _, match in query:iter_matches(root, bufnr, row, row + 1) do
    local translation_key_node = match[#match]
    local start_row, start_col, end_row, end_col = translation_key_node:range()
    if row == start_row and col >= start_col and col <= end_col then
      translation_key = ts.get_node_text(translation_key_node, bufnr)
      break
    end
  end
  return translation_key
end

return M
