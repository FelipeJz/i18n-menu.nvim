local api = vim.api
local fn = vim.fn
local M = {}
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
  if file then
    local content = file:read("*a")
    file:close()
    local config = vim.fn.json_decode(content)
    return config
  else
    print("Error: i18n-menu: i18n.json not found")
    return nil
  end
end

function M.get_translation_files()
  local project_root = M.get_project_root()

  if not project_root then
    return {}
  end

  local messages_dir = project_root .. "/messages/"
  local translation_files = fn.glob(messages_dir .. "*.json", false, true)

  return translation_files
end

return M
