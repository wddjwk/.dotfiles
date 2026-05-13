return {
    "ojroques/nvim-osc52",
    config = function()
        local osc52 = require("osc52")

        -- 任何 yank 操作都通过 OSC52 发送到系统剪贴板（类似 vim 的 TextYankPost 方式）
        vim.api.nvim_create_autocmd("TextYankPost", {
            pattern = "*",
            callback = function()
                if vim.v.event.operator == "y" then
                    local regname = vim.v.event.regname
                    -- "" (unnamed), +, * 寄存器的 yank 都触发
                    if regname == "" or regname == nil or regname == "+" or regname == "*" then
                        osc52.copy(vim.fn.getreg(regname or "+"))
                    end
                end
            end,
        })
    end,
}
