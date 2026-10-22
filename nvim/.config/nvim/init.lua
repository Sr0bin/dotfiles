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
	require("plugins.norminette"),
	require("plugins.colortheme"),
	require("plugins.render-markdown"),
	-- require("plugins.signature"),
	require("plugins.lazygit"),
})
--
-- Open a file skipping the auto-template pipeline.
-- Usage: :NoTemplate MyClass.hpp
vim.api.nvim_create_user_command("NoTemplate", function(opts)
	vim.g.skip_template_once = true
	vim.cmd("e " .. vim.fn.fnameescape(opts.args))
end, { nargs = 1, complete = "file" })

-- Helper: returns true (and consumes the flag) if the next new-file should be skipped
local function skip_once()
	if vim.g.skip_template_once then
		vim.g.skip_template_once = false
		return true
	end
	return false
end

-- Helper: returns true when the buffer is a brand-new empty file on disk
local function is_new_empty_file(buf, bufname)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines > 1 or (#lines == 1 and lines[1] ~= "") then
		return false
	end
	local stat = vim.loop.fs_stat(bufname)
	return stat ~= nil and stat.size == 0
end

-- Route new .hpp → include/ and .cpp → src/ when those dirs exist at cwd
vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = { "*.hpp", "*.cpp" },
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(buf)
		if bufname == "" then return end

		local abs_path = vim.fn.fnamemodify(bufname, ":p")
		local dir = vim.fn.fnamemodify(abs_path, ":h")
		local cwd = vim.fn.getcwd()
		if dir ~= cwd then return end

		local ext = vim.fn.fnamemodify(bufname, ":e")
		local subdir = (ext == "hpp") and "include" or "src"
		local target = cwd .. "/" .. subdir
		if vim.fn.isdirectory(target) == 0 then return end

		local new_path = target .. "/" .. vim.fn.fnamemodify(bufname, ":t")
		vim.schedule(function()
			vim.cmd("bwipeout! " .. buf)
			vim.cmd("edit " .. vim.fn.fnameescape(new_path))
		end)
	end,
})

-- Auto-populate new .hpp: 42 header + class template snippet + touch companion .cpp
vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*.hpp",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(buf)
		if skip_once() or not is_new_empty_file(buf, bufname) then
			return
		end

		local classname = vim.fn.fnamemodify(bufname, ":t:r")
		local guard = vim.fn.fnamemodify(bufname, ":t"):upper():gsub("[^A-Z0-9]", "_")

		vim.cmd("FtHeader")

		-- Touch the companion .cpp; opening it later will auto-expand the ocf snippet.
		-- Mirror the .hpp's location under include/ into src/, preserving any
		-- subdir (so include/commands/X.hpp -> src/commands/X.cpp).
		local dir = vim.fn.fnamemodify(bufname, ":h")
		local cpp_dir = dir:gsub("/include/", "/src/"):gsub("/include$", "/src")
		if cpp_dir == dir then
			-- .hpp not under include/: fall back to cwd/src if present, else same dir
			local cwd = vim.fn.getcwd()
			cpp_dir = (vim.fn.isdirectory(cwd .. "/src") == 1) and (cwd .. "/src") or dir
		end
		vim.fn.mkdir(cpp_dir, "p")
		local cpp_path = cpp_dir .. "/" .. classname .. ".cpp"
		if vim.fn.filereadable(cpp_path) == 0 then
			vim.fn.writefile({}, cpp_path)
			vim.notify(classname .. ".cpp created", vim.log.levels.INFO)
			pcall(function()
				require("neo-tree.sources.manager").refresh("filesystem")
			end)
		end

		-- Expand class template snippet — jump with <C-l> / <C-h>
		--   $1 = parameterized constructor params
		--   $2 = private members
		vim.schedule(function()
			local ls = require("luasnip")
			local snip = ls.parser.parse_snippet(
				{ trig = "" },
				table.concat({
					"#ifndef " .. guard,
					"# define " .. guard,
					"",
					"class " .. classname,
					"{",
					"public:",
					"\t" .. classname .. "(void);",
					"\t" .. classname .. "(${1:params});",
					"\t" .. classname .. "(const " .. classname .. " &other);",
					"\t" .. classname .. " &operator=(const " .. classname .. " &other);",
					"\t~" .. classname .. "(void);",
					"",
					"private:",
					"\t$2",
					"};",
					"",
					"#endif",
				}, "\n")
			)

			local line_count = vim.api.nvim_buf_line_count(buf)
			vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { "" })
			vim.api.nvim_win_set_cursor(0, { line_count + 1, 0 })
			vim.cmd("startinsert")
			ls.snip_expand(snip)
		end)
	end,
})

-- Auto-populate new .cpp: ocf snippet with classname pre-filled
-- Fires when you open the companion .cpp that was touched by the .hpp autocmd
vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*.cpp",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(buf)
		if skip_once() or not is_new_empty_file(buf, bufname) then
			return
		end

		local classname = vim.fn.fnamemodify(bufname, ":t:r")

		vim.cmd("FtHeader")

		-- Expand OCF implementation snippet — jump with <C-l> / <C-h>
		--   $1 = default ctor body
		--   $2 = parameterized ctor params
		--   $3 = parameterized ctor body
		--   $4 = assignment body
		--   $5 = destructor body
		vim.schedule(function()
			local ls = require("luasnip")
			local snip = ls.parser.parse_snippet(
				{ trig = "" },
				table.concat({
					'#include "' .. classname .. '.hpp"',
					"",
					classname .. "::" .. classname .. "(void)",
					"{",
					"\t$1",
					"}",
					"",
					classname .. "::" .. classname .. "(${2:params})",
					"{",
					"\t$3",
					"}",
					"",
					classname .. "::" .. classname .. "(const " .. classname .. " &other)",
					"{",
					"\t*this = other;",
					"}",
					"",
					classname .. " &" .. classname .. "::operator=(const " .. classname .. " &other)",
					"{",
					"\tif (this != &other)",
					"\t{",
					"\t\t$4",
					"\t}",
					"\treturn (*this);",
					"}",
					"",
					classname .. "::~" .. classname .. "(void)",
					"{",
					"\t$5",
					"}",
				}, "\n")
			)

			local line_count = vim.api.nvim_buf_line_count(buf)
			vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { "" })
			vim.api.nvim_win_set_cursor(0, { line_count + 1, 0 })
			vim.cmd("startinsert")
			ls.snip_expand(snip)
		end)
	end,
})

vim.cmd("colorscheme cyberdream")
-- require("ibl").setup()
