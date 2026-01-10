local api = vim.api
local ts = vim.treesitter

local M = {}
local util = require("i18n-menu.util")
local dig = require("i18n-menu.dig")

function M.show_key_under_cursor_menu()
	local translation_key = util.get_key_under_cursor()
	local messages_dir = util.get_messages_dir()
	local translation_files = util.get_translation_files()

	if not translation_key or not messages_dir or not translation_files then
		return
	end

	util.open_menu(translation_key, messages_dir, translation_files)
end

function M.show_buffer_keys_menu()
	local messages_dir = util.get_messages_dir()
	local translation_files = util.get_translation_files()
	local config = util.read_config_file()
	if not messages_dir or not translation_files then
		return
	end

	local keys_found = {}
	local seen = {}

	util.iter_translation_keys({
		bufnr = api.nvim_get_current_buf(),
		function_name = (config and config.function_name) or "t",
	}, function(node)
		local key = ts.get_node_text(node, api.nvim_get_current_buf())
		if key and not seen[key] then
			table.insert(keys_found, key)
			seen[key] = true
		end
	end)

	if #keys_found == 0 then
		vim.notify("No translation keys found in this buffer", vim.log.levels.WARN)
		return
	end

	table.sort(keys_found)

	vim.ui.select(keys_found, {
		prompt = "Select key from buffer:",
		format_item = function(item)
			return item
		end,
	}, function(selected_key)
		if selected_key then
			util.open_menu(selected_key, messages_dir, translation_files)
		end
	end)
end

function M.show_all_keys_menu()
	local messages_dir = util.get_messages_dir()
	local translation_files = util.get_translation_files()
	if not messages_dir or not translation_files then
		return
	end

	local keys_set = {}
	for _, file in ipairs(translation_files) do
		local translations = util.load_translations(file)
		for key, _ in pairs(translations) do
			keys_set[key] = true
		end
	end

	local sorted_keys = {}
	for key in pairs(keys_set) do
		table.insert(sorted_keys, key)
	end
	table.sort(sorted_keys)

	vim.ui.select(sorted_keys, {
		prompt = "Search all project keys:",
		format_item = function(item)
			return item
		end,
	}, function(selected_key)
		if selected_key then
			util.open_menu(selected_key, messages_dir, translation_files)
		end
	end)
end

function M.translate_default()
	local config = util.read_config_file()

	local translation_key = util.get_key_under_cursor()
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
	util.highlight_translation_references()
	M.show_key_under_cursor_menu()
end

function M.setup()
	api.nvim_command("augroup TranslateHighlight")
	api.nvim_command("autocmd!")
	api.nvim_command(
		"autocmd BufEnter,BufRead *.jsx,*.tsx lua require('i18n-menu.util').highlight_translation_references()"
	)
	api.nvim_command("autocmd InsertLeave *.jsx,*.tsx lua require('i18n-menu.util').highlight_translation_references()")
	api.nvim_command("augroup END")

	api.nvim_command("command! TranslateMenu lua require('i18n-menu').show_key_under_cursor_menu()")
	api.nvim_command("command! TranslateDefault lua require('i18n-menu').translate_default()")
	api.nvim_command("command! TranslateListAll lua require('i18n-menu').show_all_keys_menu()")
	api.nvim_command("command! TranslateListBuffer lua require('i18n-menu').show_buffer_keys_menu()")
end

return M
