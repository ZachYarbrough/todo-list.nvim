local M = {}

-- Directories/files to ignore
local blacklist_globs = {
    "node_modules/*",
    "site-packages/*",
    ".git/*",
    "__pycache__/*",
    "dist/*",
    "build/*",
}

-- Fetch TODOs using ripgrep
local function rg_todos(root)
    root = root or vim.fn.getcwd()
    local todos_by_file = {}

    local ignore_args = ""
    for _, pattern in ipairs(blacklist_globs) do
        ignore_args = ignore_args .. string.format(' --glob "!%s"', pattern)
    end

    local cmd = string.format(
        'rg --vimgrep --glob "*.py" --glob "*.lua" --glob "*.js" --glob "*.ts" --glob "*.jsx" --glob "*.tsx" --glob "*.java"%s TODO "%s"',
        ignore_args,
        root
    )

    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local filepath, lnum, text = line:match("^(.-):(%d+):(%d+):(.*)$")
            if filepath and lnum and text then
                local todo_text

                -- Python / Shell / Bash
                todo_text = text:match("(%s*#%s*TODO.*)")
                -- JS / TS / Java / C-like
                if not todo_text then
                    todo_text = text:match("(%s*//%s*TODO.*)")
                end
                -- Lua
                if not todo_text then
                    todo_text = text:match("(%s*%-%-%s*TODO.*)")
                end
                -- JSX/TSX style comment
                if not todo_text then
                    todo_text = text:match("{/%*%s*TODO.-%*/}")
                end

                if todo_text then
                    todos_by_file[filepath] = todos_by_file[filepath] or {}
                    local ext = filepath:match("%.([a-zA-Z0-9]+)$") or ""
                    table.insert(todos_by_file[filepath], string.format("%s:%s: %s", ext, lnum, todo_text))
                end
            end
        end
        handle:close()
    end

    return todos_by_file
end

-- Show TODOs in a floating buffer
function M.show_todos(root)
    local todos_by_file = rg_todos(root)

    local display_lines = {}
    local line_to_file = {} -- map buffer line number → {file, line}

    for filepath, todos in pairs(todos_by_file) do
        local relpath = vim.fn.fnamemodify(filepath, ":.")  -- relative path
        table.insert(display_lines, relpath .. ":")
        line_to_file[#display_lines] = { file = filepath, line = 1 } -- file header → start of file

        for _, t in ipairs(todos) do
            local ext, lnum, todo_text = t:match("^(.-):(%d+):%s*(.*)$")
            if ext and lnum and todo_text then
                local display_line = string.format("%s:%s: %s", ext, lnum, todo_text) -- indent TODO
                table.insert(display_lines, display_line)
                line_to_file[#display_lines] = { file = filepath, line = tonumber(lnum) }
            end
        end

        table.insert(display_lines, "") -- blank line between files
    end

    local pad_left = 2

    -- Left padding
    for i, line in ipairs(display_lines) do
	display_lines[i] = string.rep(" ", pad_left) .. line
    end

    -- Create buffer and mark as TODO
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_var(buf, "is_todo_buffer", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

    -- Make buffer read only
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")  -- buffer isn’t associated with a file
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")  -- delete buffer when closed
    vim.api.nvim_buf_set_option(buf, "swapfile", false)    -- no swap
    vim.api.nvim_buf_set_option(buf, "modifiable", false)  -- cannot modify contents
    vim.api.nvim_buf_set_option(buf, "readonly", true)     -- readonly flag
    vim.api.nvim_buf_set_keymap(buf, "n", "i", "<nop>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "I", "<nop>", { noremap = true, silent = true })

    -- Enable line numbers
    vim.api.nvim_buf_set_option(buf, "number", true)
    vim.api.nvim_buf_set_option(buf, "relativenumber", false) -- optional
    vim.api.nvim_buf_set_option(buf, "signcolumn", "no")       -- optional

    -- Compute window size
    local width = math.floor(vim.o.columns * 0.6)
    local max_height = math.floor(vim.o.lines * 0.8)
    local min_height = 8
    local height = math.min(#display_lines, max_height)
    height = math.max(height, min_height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Open floating window with centered title
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " ToDo List ",
        title_pos = "center",
        noautocmd = true,
    })

    -- Highlight the "ext:lnum:" like line numbers
    for i, line in ipairs(display_lines) do
        local start_col, end_col = line:find("%s*[%a]+:%d+:")
        if start_col and end_col then
            vim.api.nvim_buf_add_highlight(buf, -1, "LineNr", i - 1, start_col - 1, end_col)
        end
    end

    -- map q / Esc to close
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>bd!<CR>", { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>bd!<CR>", { silent = true, noremap = true })

    -- map Enter to open TODO line or file header
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = function()
            local line_nr = vim.api.nvim_win_get_cursor(0)[1]
            local meta = line_to_file[line_nr]
            if not meta then
                print("Not a valid line")
                return
            end

        -- Close the floating window safely
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end

        -- Delete the buffer safely
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end

        -- Open the target file
        vim.cmd(string.format("edit %s", meta.file))
        vim.api.nvim_win_set_cursor(0, { meta.line, 0 })
    end
    })
end

-- Command
vim.api.nvim_create_user_command("ShowTodos", function()
    M.show_todos()
end, {})

-- Leader mapping with buffer toggle
vim.keymap.set('n', '<C-t>', function()
    local todo_buf, todo_win

    -- Search for existing TODO buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local ok, is_todo = pcall(vim.api.nvim_buf_get_var, buf, "is_todo_buffer")
            if ok and is_todo then
                todo_buf = buf
                break
            end
        end
    end

    if todo_buf then
        -- Close window if visible
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == todo_buf then
                todo_win = win
                break
            end
        end
        if todo_win then
            pcall(vim.api.nvim_win_close, todo_win, true)
        end
        pcall(vim.api.nvim_buf_delete, todo_buf, { force = true })
        return
    end

    -- Open new TODO buffer
    vim.schedule(function()
        vim.cmd(":ShowTodos")
    end)
end, { noremap = true, silent = true })
