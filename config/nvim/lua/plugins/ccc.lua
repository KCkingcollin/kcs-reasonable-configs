return {
    'uga-rosa/ccc.nvim',
    config = function()
        local ccc = require("ccc")
        ccc.setup({
            pickers = {
                ccc.picker.custom_entries({
                    red = "#BF616A",
                    green = "#A3BE8C",
                    blue = "#81A1C1",
                }),
                ccc.picker.ansi_escape()
            },
        })
    end
}
