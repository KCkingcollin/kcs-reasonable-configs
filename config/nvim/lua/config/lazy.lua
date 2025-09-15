-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
    spec = {
        { 'rose-pine/neovim', name = 'rose-pine' },

        {
            'nvim-telescope/telescope.nvim', tag = '0.1.8',
            requires = { {'nvim-lua/plenary.nvim'} }
        },

        {"nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate"},
        {
            "ThePrimeagen/harpoon",
            branch = "harpoon2",
            requires = { {"nvim-lua/plenary.nvim"} }
        },
        {"mbbill/undotree"},
        {"tpope/vim-fugitive"},
        {"tribela/vim-transparent"},

        -- lsp
        {
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "hrsh7th/nvim-cmp",
            "f3fora/cmp-spell",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "j-hui/fidget.nvim",
            "neovim/nvim-lspconfig",
        },
        {"theprimeagen/vim-be-good"},
        {"gbprod/yanky.nvim"},

        -- debugging
        {
            "mfussenegger/nvim-dap",
            "rcarriga/nvim-dap-ui",
            "theHamsta/nvim-dap-virtual-text",
            "leoluz/nvim-dap-go",
            "nvim-neotest/nvim-nio"
        },
        {'hrsh7th/cmp-vsnip'},
        {'hrsh7th/vim-vsnip'},
        {'dcampos/nvim-snippy'},
        {'dcampos/cmp-snippy'},
        {
            "windwp/nvim-autopairs",
            event = "InsertEnter",
            config = function()
                require("nvim-autopairs").setup {}
            end
        },
        {'filNaj/tree-setter'},
        {'saifulapm/commasemi.nvim'},
        { import = "plugins" },
    },
    -- Configure any other settings here. See the documentation for more details.
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "habamax" } },
    -- automatically check for plugin updates
    checker = {
        enabled = true,
        notify = false,
        frequency = 3600,
    },
    change_detection = {
        enabled = true,
        notify = false,
    },
})
