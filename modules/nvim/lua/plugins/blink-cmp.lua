local blink = require("blink.cmp")

blink.setup({
	enabled = function()
		local ft = vim.bo.filetype
		return ft ~= "markdown" and ft ~= "text"
	end,
	keymap = {
		preset = "none",
		["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
		["<C-e>"] = { "hide", "fallback" },
		["<CR>"] = { "accept", "fallback" },
		["<Tab>"] = { "select_next", "fallback" },
		["<S-Tab>"] = { "select_prev", "fallback" },
		["<C-n>"] = { "select_next", "fallback_to_mappings" },
		["<C-p>"] = { "select_prev", "fallback_to_mappings" },
		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		["<C-f>"] = { "scroll_documentation_down", "fallback" },
		["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
	},
	completion = {
		keyword = { range = "prefix" },
		list = {
			selection = {
				preselect = true,
				auto_insert = false,
			},
		},
		accept = {
			auto_brackets = {
				enabled = true,
			},
		},
		ghost_text = {
			enabled = false,
		},
		menu = {
			auto_show = true,
			draw = {
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
				treesitter = { "lsp" },
			},
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 250,
		},
	},
	signature = {
		enabled = true,
		trigger = {
			show_on_accept = true,
		},
	},
	snippets = {
		preset = "default",
	},
	cmdline = {
		keymap = {
			preset = "none",
			["<Tab>"] = { "select_next", "fallback" },
			["<S-Tab>"] = { "select_prev", "fallback" },
			["<C-Space>"] = { "show", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<C-y>"] = { "select_and_accept", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<C-e>"] = { "cancel", "fallback" },
		},
		completion = {
			list = {
				selection = {
					preselect = false,
					auto_insert = false,
				},
			},
			ghost_text = {
				enabled = false,
			},
			menu = {
				auto_show = false,
				draw = {
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
				},
			},
		},
	},
})
