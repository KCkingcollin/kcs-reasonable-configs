local fn = vim.fn

local packer_install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

local function ensure_packer()
    if fn.empty(fn.glob(packer_install_path)) > 0 then
        print("Installing packer.nvim...")
        vim.notify("Installing Packer.nvim...", vim.log.levels.INFO, { title = "Packer" })
        local status, result = pcall(fn.system, {
            'git', 'clone', '--depth', '1',
            'https://github.com/wbthomason/packer.nvim',
            packer_install_path
        })

        if not status then
            vim.notify("Failed to clone Packer.nvim: " .. tostring(result), vim.log.levels.ERROR, { title = "Packer Error" })
            return false
        else
            vim.notify("Packer.nvim installed successfully!", vim.log.levels.INFO, { title = "Packer" })
            vim.cmd 'packadd packer.nvim'
            -- Only return true if packer needed to be installed and did so successfully
            return true
        end
    end
    return false
end

local packerFreshInstall = ensure_packer()

require('packer').startup(function(use)
    -- Packer can manage itself
    use("wbthomason/packer.nvim")

    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.6',
        -- or                            , branch = '0.1.x',
        requires = { {'nvim-lua/plenary.nvim'} }
    }
    --	use { "rose-pine/neovim", as = "rose-pine" }
    use({
        'rose-pine/neovim',
        as = 'rose-pine',
        config = function()
            vim.cmd('colorscheme rose-pine')
        end
    })

    use('nvim-treesitter/nvim-treesitter', {run = ':TSUpdate'})
    use('nvim-treesitter/playground')
    use "nvim-lua/plenary.nvim"
    use {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        requires = { {"nvim-lua/plenary.nvim"} }
    }
    use("mbbill/undotree")
    use("tpope/vim-fugitive")
    use("tribela/vim-transparent")

    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            --- Uncomment the two plugins below if you want to manage the language servers from neovim
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
        }
    }
    -- use ('alexghergh/nvim-tmux-navigation')
    use("theprimeagen/vim-be-good")
    use("gbprod/yanky.nvim")
    -- debugging
    use {
        "mfussenegger/nvim-dap",
        "rcarriga/nvim-dap-ui",
        "theHamsta/nvim-dap-virtual-text",
        "leoluz/nvim-dap-go",
        "nvim-neotest/nvim-nio"
    }
    use('hrsh7th/cmp-vsnip')
    use('hrsh7th/vim-vsnip')
    use('dcampos/nvim-snippy')
    use('dcampos/cmp-snippy')
    use {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup {}
        end
    }
    use('filNaj/tree-setter')
    use('saifulapm/commasemi.nvim')
end)

if packerFreshInstall then
    vim.cmd('PackerSync')
end
