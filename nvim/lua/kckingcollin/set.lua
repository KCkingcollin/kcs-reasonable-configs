-- Function to enable wrap if buffer is empty (new file)
local function enable_wrap_if_empty()
    if vim.fn.line2byte('$') == -1 then
        vim.wo.wrap = true
        vim.wo.linebreak = true
    end
end

-- Helper function to check if wrap should be enabled based on filetype
local function should_enable_wrap()
    local filetype = vim.bo.filetype
    local wrap_filetypes = { "markdown", "text", "txt", "md" } -- Add your new filetype here
    for _, ft in ipairs(wrap_filetypes) do
        if filetype == ft then
            return true
        end
    end
    return false
end

vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.g.mapleader = " "

vim.opt.spelllang = 'en_us'
vim.opt.spell = true

vim.opt.wrap = false

vim.opt.clipboard = "unnamedplus"

-- Autocommands for specific file types
vim.api.nvim_create_autocmd({'BufRead', 'BufNewFile'}, {
    pattern = {'*.txt', '*.md'}, -- Add your new file extension here
    callback = function()
        vim.wo.wrap = true
        vim.wo.linebreak = true
    end,
})

-- Autocommand for startup with an empty buffer
vim.api.nvim_create_autocmd('BufWinEnter', {
    callback = function()
        enable_wrap_if_empty()
    end,
})

-- Autocommand for when a new buffer is created
vim.api.nvim_create_autocmd('BufNewFile', {
    callback = function()
        enable_wrap_if_empty()
    end,
})

-- Autocommand for buffer enter
vim.api.nvim_create_autocmd('BufEnter', {
    callback = function()
        if vim.bo.filetype == "" then
            enable_wrap_if_empty()
        elseif should_enable_wrap() then
            vim.wo.wrap = true
            vim.wo.linebreak = true
        else
            vim.wo.wrap = false
            vim.wo.linebreak = false
        end
    end,
})

-- Autocommand for buffer read post
vim.api.nvim_create_autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        if should_enable_wrap() then
            vim.wo.wrap = true
        else
            vim.wo.wrap = false
        end
    end,
})
