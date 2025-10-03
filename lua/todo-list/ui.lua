local config = require("todo-list.config")

local M = {}

local state = { buf = nil, win = nil }

function M.render(todos_by_file)
    if vim.tbl_isempty(todos_by_file) then
        todos_by_file = { ["No TODOs found"] = {} }
    end

    local display_lines, line_to_file = {}, {}

    for filepath, todos in pairs(todos_by_file) do
        local relpath = vim.fn.fnamemodify(filepath, ":.")
        table.insert(display_lines, relpath .. ":")
        line_to_file[#display_lines] = { file = filepath, line = 1 }

        for _, t in ipairs(todos) do
            local ext, lnum, todo_text = t:match("^(.-):(%d+):%s*(.*)$")
            if ext and lnum and todo_text then
                table.insert(display_lines, string.format("%s:%s: %s", ext, lnum, todo_text))
                line_to_file[#display_lines] = { file = filepath, line = tonumber(lnum) }
            end
        end

        table.insert(display_lines, "")
    end

    -- Apply padding
    for i, line in ipairs(display_lines) do
        display_lines[i] = string.rep(" ", config.options.padding.left) .. line
    end

    -- Create buffer
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_var(state.buf, "is_todo_buffer", true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_option(state.buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(state.buf, "modifiable", false)
    vim.api.nvim_buf_set_option(state.buf, "readonly", true)
    vim.api.nvim_buf_set_option(state.buf, "number", true)

    -- Floating window
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.min(#display_lines, math.floor(vim.o.lines * 0.8))
    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = "editor",
        width = width,
        height = math.max(height, 8),
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " ToDo List ",
        title_pos = "center",
    })

    -- Mappings
    vim.keymap.set("n", "q", "<cmd>bd!<CR>", { buffer = state.buf })
    vim.keymap.set("n", "<Esc>", "<cmd>bd!<CR>", { buffer = state.buf })
    vim.keymap.set("n", "<CR>", function()
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local meta = line_to_file[line_nr]
        if not meta or not meta.file:match("%.") then return end

        vim.api.nvim_win_close(state.win, true)
        vim.api.nvim_buf_delete(state.buf, { force = true })

        vim.cmd("edit " .. meta.file)
        vim.api.nvim_win_set_cursor(0, { meta.line, 0 })
    end, { buffer = state.buf })
end

function M.toggle()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_close(state.win, true)
        end
        vim.api.nvim_buf_delete(state.buf, { force = true })
        state.buf, state.win = nil, nil
    else
        vim.cmd("ShowTodos")
    end
end

return M

