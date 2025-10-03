local M = {}

local config = require("todo-list.config")
local ui = require("todo-list.ui")
local search = require("todo-list.search")

function M.setup(opts)
    config.setup(opts or {})

    vim.api.nvim_create_user_command("ShowTodos", function()
        M.show_todos()
    end, {})

    -- Default keymap
    vim.keymap.set("n", "<C-t>", function()
        M.toggle()
    end, { noremap = true, silent = true })
end

function M.show_todos(root)
    local todos = search.scan(root)
    ui.render(todos)
end

function M.toggle()
    ui.toggle()
end

return M

