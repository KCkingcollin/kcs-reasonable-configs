vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('user_lsp_attach', {clear = true}),
  callback = function(event)
    local opts = {buffer = event.buf}

    vim.keymap.set('n', 'gd', function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set('n', '<leader>i', function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set('n', 'K', function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set('n', '<leader>vws', function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set('n', '<leader>vd', function() vim.diagnostic.open_float() end, opts)
    vim.keymap.set('n', '<leader>vca', function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set('n', '<leader>vrr', function() vim.lsp.buf.references() end, opts)
    vim.keymap.set('n', '<leader>vrn', function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set('i', '<C-h>', function() vim.lsp.buf.signature_help() end, opts)
  end,
})

local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()

require('cmp_nvim_lsp').setup({
  -- Enable auto-completion
  auto_complete = true,
  -- Enable snippet expansion
  snippet_expansion = true,
})

require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {'bashls', 'lua_ls', 'glslls'},
})

vim.lsp.config(
    "lua_ls", {
        settings = {
            Lua = {
                runtime = {
                    version = 'LuaJIT' -- Specifies the Lua runtime version
                },
                diagnostics = {
                    globals = {'vim'}, -- This tells the LSP to recognize 'vim' as a global
                },
                workspace = {
                    library = {
                        vim.env.VIMRUNTIME, -- This points the LSP to the Neovim runtime files for definitions
                    }
                },
                format = {
                    insertSpaces = true,
                },
            },
        }
    },
    "glslls", {
        filetypes = { "glsl", "vert", "frag", "geom", "comp" },
        flags = {
            debounce_text_changes = 150,
        },
    },
    "glsl_analyzer", {
        filetypes = { "glsl", "vert", "frag", "geom", "comp" },
        flags = {
            debounce_text_changes = 150,
        },
    }
)

vim.filetype.add({
    extension = {
        vert = "glsl",
        frag = "glsl",
        geom = "glsl",
        comp = "glsl",
        glsl = "glsl",
    },
})

local cmp = require('cmp')
local cmp_select = {behavior = cmp.SelectBehavior.Select}

-- this is the function that loads the extra snippets to luasnip
-- from rafamadriz/friendly-snippets
require('luasnip.loaders.from_vscode').lazy_load()

cmp.setup({
  sources = {
    {name = 'path'},
    {name = 'nvim_lsp'},
    {name = 'luasnip', keyword_length = 2},
    {name = 'buffer', keyword_length = 3},
    {
            name = "spell",
            option = {
                keep_all_entries = false,
                enable_in_context = function()
                    return true
                end,
                preselect_correct_word = false,
        },
    },
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
    ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
    ['<M-k>'] = cmp.mapping.select_prev_item(cmp_select),
    ['<M-j>'] = cmp.mapping.select_next_item(cmp_select),
    ['<Tab>'] = cmp.mapping.confirm({ select = true }),
    ['<C-Space>'] = cmp.mapping.complete(),
  }),
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
})
