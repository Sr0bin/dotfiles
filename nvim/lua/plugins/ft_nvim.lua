return {
	"vinicius507/ft_nvim",
	dependencies = {
		"mfussenegger/nvim-lint",
	},
	cmd = { "FtHeader", "Norme" }, -- Lazy load the commands.
	ft = { "c", "cpp" }, -- Lazy load for .c and .h files.
	opts = {},
	config = function()
		require("ft_nvim").setup({
			-- Configures the 42 Header integration
			header = {
				-- Enable the 42 Header integration (default: true).
				enable = true,
				-- Your Intranet username (default: "marvin").
				username = "rorollin",
				-- Your Intranet email (default: "marvin@42.fr").
				email = "rorollin@student.42lyon.fr",
			},
			-- Configures the norminette integration.
			norminette = {
				-- Enable the norminette integration (default: true).
				enable = true,
				-- The command to run norminette (default: "norminette").
				cmd = "norminette",
				-- A function to conditionally enable the norminette integration (default: nil)
				condition = function()
					return true
				end,
			},
		})
	end,
}
