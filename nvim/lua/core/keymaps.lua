-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable the spacebar key's default behavior in Normal and Visual modes
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- For conciseness
local opts = { noremap = true, silent = true }

-- save file
vim.keymap.set("n", "<C-a>", "<cmd> w <CR>", opts)

-- save file without auto-formatting
vim.keymap.set(
	"n",
	"<leader>sn",
	"<cmd>noautocmd w <CR>",
	vim.tbl_extend("force", opts, { desc = "[S]ave file with [n]o formatting" })
)

-- quit file
vim.keymap.set("n", "<C-q>", "<cmd> q <CR>", opts)

-- delete single character without copying into register
vim.keymap.set("n", "x", '"_x', opts)

-- Vertical scroll and center
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)

-- Find and center
vim.keymap.set("n", "n", "nzzzv", opts)
vim.keymap.set("n", "N", "Nzzzv", opts)

-- Resize with arrows
vim.keymap.set("n", "<Up>", ":resize -2<CR>", opts)
vim.keymap.set("n", "<Down>", ":resize +2<CR>", opts)
vim.keymap.set("n", "<Left>", ":vertical resize -2<CR>", opts)
vim.keymap.set("n", "<Right>", ":vertical resize +2<CR>", opts)

-- Buffers
vim.keymap.set("n", "<Tab>", ":bnext<CR>", opts)
vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>", opts)
vim.keymap.set("n", "<leader>x", ":bdelete!<CR>", vim.tbl_extend("force", opts, { desc = "Close buffer" })) -- close buffer
vim.keymap.set("n", "<leader>b", "<cmd> enew <CR>", vim.tbl_extend("force", opts, { desc = "New [B]uffer" })) -- new buffer

-- Window management
vim.keymap.set("n", "<leader>v", "<C-w>v", vim.tbl_extend("force", opts, { desc = "Split window [V]ertically" })) -- split window vertically
vim.keymap.set("n", "<leader>h", "<C-w>s", vim.tbl_extend("force", opts, { desc = "Split window [H]orizontally" })) -- split window horizontally
vim.keymap.set(
	"n",
	"<leader>se",
	"<C-w>=",
	vim.tbl_extend("force", opts, { desc = "Make [S]plit window [E]qual width & heigth" })
) -- make split windows equal width & height
vim.keymap.set("n", "<leader>xs", ":close<CR>", opts) -- close current split window

-- Navigate between splits
vim.keymap.set("n", "<C-k>", ":wincmd k<CR>", opts)
vim.keymap.set("n", "<C-j>", ":wincmd j<CR>", opts)
vim.keymap.set("n", "<C-h>", ":wincmd h<CR>", opts)
vim.keymap.set("n", "<C-l>", ":wincmd l<CR>", opts)

-- Tabs
vim.keymap.set("n", "<leader>to", ":tabnew<CR>", opts) -- open new tab
vim.keymap.set("n", "<leader>tx", ":tabclose<CR>", opts) -- close current tab
vim.keymap.set("n", "<leader>tn", ":tabn<CR>", opts) --  go to next tab
vim.keymap.set("n", "<leader>tp", ":tabp<CR>", opts) --  go to previous tab

-- Toggle line wrapping
vim.keymap.set("n", "<leader>lw", "<cmd>set wrap!<CR>", opts)

-- Stay in indent mode
vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- Keep last yanked when pasting
vim.keymap.set("v", "p", '"_dP', opts)

-- Diagnostic keymaps
-- vim.keymap.set("n", "[d", vim.diagnostic.get_prev, { desc = "Go to previous diagnostic message" })
-- vim.keymap.set("n", "]d", vim.diagnostic.get_next, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- FtHeader
vim.keymap.set("n", "<F2>", ":FtHeader<CR>", opts)

--Cheatsheet
vim.keymap.set("n", "<F3>", ":Cheatsheet<CR>", opts)

-- Norminette Toggle
local norminette_enabled = true

local function toggle_norminette()
	if norminette_enabled then
		vim.cmd("NorminetteDisable")
	else
		vim.cmd("NorminetteEnable")
	end
	norminette_enabled = not norminette_enabled
end

vim.keymap.set("n", "<F4>", toggle_norminette, vim.tbl_extend("force", opts, { desc = "Toggle Norminette" }))
-- Signature
vim.keymap.set({ "n" }, "<F5>", function()
	require("lsp_signature").toggle_float_win()
end, { silent = true, noremap = true, desc = "toggle signature" })

vim.keymap.set({ "n" }, "<Leader>k", function()
	vim.lsp.buf.signature_help()
end, { silent = true, noremap = true, desc = "toggle signature" })
