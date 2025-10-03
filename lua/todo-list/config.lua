local M = {}

M.options = {
    blacklist = {
        "node_modules/*",
        "site-packages/*",
        ".git/*",
        "__pycache__/*",
        "dist/*",
        "build/*",
    },
    padding = { left = 2, top = 0, bottom = 0 },
}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M

