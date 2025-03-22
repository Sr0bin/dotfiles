return {

	"jay-babu/mason-nvim-dap.nvim",
	dependencies = {
		{ "mfussenegger/nvim-dap" },
	},
	config = function()
		require("mason-nvim-dap").setup({
			ensure_installed = { "cppdbg" },
		}) -- sets up dap in the predefined manner
	end,
}
