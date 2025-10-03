local M = {}

local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "CursorLine" })
local default_cursorline_bg = (ok and hl.bg) and string.format("#%06x", hl.bg) or "#2e2e2e"

M.defaults = {
    blacklist = {
        "node_modules/*",
        "site-packages/*",
        ".git/*",
        "__pycache__/*",
        "dist/*",
        "build/*",
    },
    line_number_mode = "none", -- "none", "absolute", "realtive"
    padding_left = 2,
    cursorline = true,
    cursorline_bg = default_cursorline_bg,
}

-- Store active options
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
