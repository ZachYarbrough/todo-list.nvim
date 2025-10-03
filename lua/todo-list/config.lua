local M = {}

M.defaults = {
    blacklist = {
        "node_modules/*",
        "site-packages/*",
        ".git/*",
        "__pycache__/*",
        "dist/*",
        "build/*",
    },
    show_line_numbers = false,
    padding_left = 2,
    highlight_line = true
}

-- Store active options
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
