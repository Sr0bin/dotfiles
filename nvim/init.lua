require("core.options")
require("core.keymaps")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	require("plugins.nvim-lint"),
	require("plugins.neotree"),
	require("plugins.bufferline"),
	require("plugins.lualine"),
	require("plugins.treesitter"),
	require("plugins.telescope"),
	require("plugins.lsp"),
	require("plugins.autocompletion"),
	require("plugins.autoformatting"),
	require("plugins.ft_nvim"),
	require("plugins.gitsigns"),
	require("plugins.mini-identscope"),
	require("plugins.misc"),
	require("plugins.cheatsheet"),
	require("plugins.dap"),
	require("plugins.norminette"),
	require("plugins.colortheme"),
	require("plugins.signature"),
	-- require("plugins.lazygit"), one day, if I install LazyGit
})
--
-- Define Header42WithGuard command
vim.api.nvim_create_user_command("Header42WithGuard", function()
	local bufname = vim.api.nvim_buf_get_name(0)
	local ext = bufname:match("^.+(%..+)$")

	if ext ~= ".h" then
		return
	end

	-- Check if file is empty to avoid overwriting
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local is_empty = #lines == 0 or (#lines == 1 and lines[1] == "")

	if not is_empty then
		vim.notify("Header42WithGuard skipped: file not empty", vim.log.levels.INFO)
		return
	end

	-- Call 42 header generator
	vim.cmd("FtHeader")

	-- Generate macro guard
	local filename = vim.fn.fnamemodify(bufname, ":t"):upper():gsub("[^A-Z0-9]", "_")
	local guard_lines = {
		"#ifndef " .. filename,
		"# define " .. filename,
		"",
		"#endif",
	}

	-- Insert after 42 header (assumed to be 11 lines)
	local insert_line = 12
	vim.api.nvim_buf_set_lines(0, insert_line, insert_line, false, guard_lines)

	-- Move cursor to the blank line between define and endif
	vim.api.nvim_win_set_cursor(0, { insert_line + 3, 0 })
end, {})

vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*.h",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

		-- skip if file isn't empty
		if #lines > 1 or (#lines == 1 and lines[1] ~= "") then
			return
		end

		-- skip if file size isn't 0 (Neo-tree creates the file early)
		local filepath = vim.api.nvim_buf_get_name(buf)
		local stat = vim.loop.fs_stat(filepath)
		if not stat or stat.size ~= 0 then
			return
		end

		vim.cmd("Header42WithGuard")
	end,
})

vim.cmd("colorscheme cyberdream")
-- require("ibl").setup()
