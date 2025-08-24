local fn = vim.fn

local packer_install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

local function ensure_packer()
    if fn.empty(fn.glob(packer_install_path)) > 0 then
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
            return true
        end
    end
    return false
end

local packerInstalled = ensure_packer()

if packerInstalled then
    vim.cmd('PackerSync')
end

if vim.fn.exists("v:shell_error") == 1 and vim.v.shell_error ~= 0 then
    vim.cmd("cq")
end

vim.cmd("quitall")
