vim.g.mapleader = " "
vim.keymap.set("i", ",", ", ")
vim.keymap.set("i", "<c-l>", [[<Esc>"+l]])
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("n", "U", vim.cmd.redo)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-j>", "<C-d>zz")
vim.keymap.set("n", "<C-k>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- vim.keymap.set("n", "<leader>vwm", function()
--     require("vim-with-me").StartVimWithMe()
-- end)
-- vim.keymap.set("n", "<leader>svwm", function()
--     require("vim-with-me").StopVimWithMe()
-- end)

-- greatest remap ever
vim.keymap.set("x", "<leader>p", [["_dP]])

-- next greatest remap ever : asbjornHaland
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

vim.keymap.set("n", "<leader>k", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<S-k>", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<S-j>", "<cmd>lprev<CR>zz")

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set(
    "n",
    "<leader>ee",
    "oif err != nil {<CR>}<Esc>Oreturn err<Esc>"
)

-- C set up
vim.keymap.set(
    "n",
    "<leader>C",
    "i#include <stdio.h> <CR><CR>int main() {<CR>}<Esc>ko"
)

-- GO set up
vim.keymap.set(
    "n",
    "<leader>GO",
    "ipackage main <CR><CR>func main() {<CR>}<Esc>ko"
)

-- GO glsl set up
vim.keymap.set(
    "n",
    "<leader>glc",
    "ipackage main <CR><CR>import (<CR>\"github.com/KCkingcollin/go-help-func/glf\"<CR>)<CR><CR>func main() {<CR>}<Esc>ko"
    )
vim.keymap.set("n", "<leader>vpp", "<cmd>e ~/.dotfiles/nvim/.config/nvim/lua/theprimeagen/packer.lua<CR>");
vim.keymap.set("n", "<leader>mr", "<cmd>CellularAutomaton make_it_rain<CR>");

-- vim.keymap.set("n", "<leader><leader>", function()
--     vim.cmd("so")
-- end)
vim.keymap.set("n", "<leader>m", function()
    vim.cmd("vsplit")
    vim.cmd("edit ~/.config/nvim/lua/kckingcollin/remap.lua")
end)

local function has_diagnostics(bufnr)
    local diagnostics = vim.diagnostic.get(bufnr or 0)
    return #diagnostics > 0
end

if has_diagnostics() then
    print("Current buffer has diagnostics!")
else
    print("No diagnostics in the current buffer.")
end

vim.keymap.set('n', '<leader>h', function()
    if has_diagnostics then
        vim.cmd('normal! [s')
    else
        vim.diagnostic.jump({count = 1})
    end
end)

vim.keymap.set('n', '<leader>l', function()
    if has_diagnostics then
        vim.cmd('normal! ]s')
    else
        vim.diagnostic.jump({count = -1})
    end
end)

-- everyone but the normys will hate this
vim.keymap.set({ "n", "i", "v" }, "<C-s>", vim.cmd.w)

vim.keymap.set({ "n", "i", "v" }, "<C-z>", vim.cmd.undo)

vim.keymap.set({ "n", "i", "v" }, "<C-y>", vim.cmd.redo)

-- vim.keymap.set("n", "<LeftMouse>", "i<LeftMouse>")
-- vim.keymap.set("v", "<LeftMouse>", "<S-i><LeftMouse>")

-- This is going to get me canceled
vim.keymap.set("v", "<C-c>", [["+y]])

vim.keymap.set("v", "<C-v>", [["+p]])
vim.keymap.set("i", "<C-v>", [[<Esc>"+p]])

vim.keymap.set("i", "<C-f>", "<Esc>/")

vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)")
vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)")

vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)")
vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)")

-- C-p/n to Alt-j/k remap
vim.keymap.set('c', '<M-k>', '<up>')
vim.keymap.set('c', '<M-j>', '<down>')

-- quick term em
vim.api.nvim_set_keymap('n', '<leader>t', ':below 6sp<CR>:terminal<CR>i<CR>clear<CR>', { noremap = true, silent = true })

-- debugging
vim.api.nvim_set_keymap('n', '<leader>9', ':lua require"dapui".toggle()<CR>:lua require"dap".continue()<CR>',
    { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>8', ':lua require"dapui".toggle()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>1', ':lua require"dap".continue()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>2', ':lua require("dapui").eval()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>3', ":lua require('dap-go').debug_test()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>4', ":lua require('dap-go').debug_last_test()", { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>5', ':lua require"dap".step_over()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>6', ':lua require"dap".step_into()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>7', ':lua require"dap".step_out()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>b', ':lua require"dap".toggle_breakpoint()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>bb', 'lua require("dap").clear_breakpoints()<CR>',
    { noremap = true, silent = true })
