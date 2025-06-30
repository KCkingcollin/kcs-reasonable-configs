vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
vim.opt.undolevels = 10000
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
