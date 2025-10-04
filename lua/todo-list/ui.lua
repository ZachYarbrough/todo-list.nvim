
local config = require("todo-list.config")

local M = {}

local state = { buf = nil, win = nil, origin_win = nil }

local function safe_close_win(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    local win_buf = vim.api.nvim_win_get_buf(win)
    local ok, is_todo = pcall(vim.api.nvim_buf_get_var, win_buf, "is_todo_buffer")
    if ok and is_todo then
      local wins = vim.api.nvim_tabpage_list_wins(0)
      if #wins > 1 then
        pcall(vim.api.nvim_win_close, win, true)
      else
        vim.cmd("hide") -- fallback
      end
    end
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local ok, is_todo = pcall(vim.api.nvim_buf_get_var, buf, "is_todo_buffer")
    if ok and is_todo then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

local function safe_delete_buf(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
    end
end

function M.render(todos_by_file)
    state.origin_win = vim.api.nvim_get_current_win()
    local display_lines, line_to_file = {}, {}
    local pad_left = string.rep(" ", config.options.padding_left)

    for filepath, todos in pairs(todos_by_file) do
        local relpath = vim.fn.fnamemodify(filepath, ":.")
        table.insert(display_lines, pad_left .. relpath .. ":")
        line_to_file[#display_lines] = { file = filepath, line = 1 }


	for _, t in ipairs(todos) do
	    local ext, lnum, todo_text = t:match("^(.-):(%d+):%s*(.*)$")
	    if ext and lnum and todo_text then
		-- find the first keyword (TODO, FIXME, BUG) in the line
		local start_idx = todo_text:find("%f[%w]TODO%f[%W]") or
				  todo_text:find("%f[%w]FIXME%f[%W]") or
				  todo_text:find("%f[%w]BUG%f[%W]")
		if start_idx then
		    todo_text = todo_text:sub(start_idx)
		end

		local line = pad_left .. string.format("%s:%s: %s", ext, lnum, todo_text)
		table.insert(display_lines, line)
		line_to_file[#display_lines] = { file = filepath, line = tonumber(lnum) }
	    end
	end

        table.insert(display_lines, "")
    end

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      vim.notify("todo-list: failed to create buffer", vim.log.levels.ERROR)
      return
    end

    state.buf = buf
    vim.api.nvim_buf_set_var(buf, "is_todo_buffer", true)

    -- Set lines before making buffer readonly
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

    -- Now mark it as special
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true

    -- Create window
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.min(#display_lines, math.floor(vim.o.lines * 0.8))
    -- Create window
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = math.max(height, 8),
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
      title = " Todo List ",
      title_pos = "center",
    })
    if not (win and vim.api.nvim_win_is_valid(win)) then
      vim.notify("todo-list: failed to open window", vim.log.levels.ERROR)
      return
    end

    state.win = win
    vim.api.nvim_set_current_win(win)

    -- Highlight ext:lnum:
    for i, line in ipairs(display_lines) do
        local s, e = line:find("%s*[%a]+:%d+:")
        if s and e then
            vim.api.nvim_buf_add_highlight(buf, -1, "LineNr", i - 1, s - 1, e)
        end
    end

    vim.wo[state.win].cursorline = config.options.cursorline

    if config.options.cursorline then
	vim.wo[win].cursorline = true
	vim.cmd(string.format("highlight TodoCursorLine guibg=%s", config.options.cursorline_bg))
	vim.wo[win].winhighlight = "CursorLine:TodoCursorLine"
    end

    -- Enable/Disable absolute and realtive line numbers
    if config.options.line_number_mode == "absolute" then
	vim.wo[win].number = true
	vim.wo[win].relativenumber = false
    elseif config.options.line_number_mode == "relative" then
	vim.wo[win].number = true
	vim.wo[win].relativenumber = true
    else
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
    end

    vim.wo[win].signcolumn = "no"
    vim.wo[win].foldcolumn = "0"

    -- Keymaps
    local close_buf_win = function()
        safe_close_win(win, buf)
        safe_delete_buf(buf)
        state.win, state.buf = nil, nil
        if state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
            vim.api.nvim_set_current_win(state.origin_win)
        end
    end

    vim.keymap.set("n", "q", close_buf_win, { buffer = buf })
    vim.keymap.set("n", "<Esc>", close_buf_win, { buffer = buf })

    vim.keymap.set("n", "<CR>", function()
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local meta = line_to_file[line_nr]
        if not meta or not meta.file:match("%.") then return end
        close_buf_win()
        vim.cmd(string.format("edit %s", meta.file))
        vim.api.nvim_win_set_cursor(0, { meta.line, 0 })
    end, { buffer = buf })
end

function M.toggle()
    -- Prefer cached state.buf
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        safe_close_win(state.win, state.buf)
        safe_delete_buf(state.buf)
        state.win, state.buf, state.origin_win = nil, nil, nil
        return
    end

    -- Fallback: scan buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local ok, is_todo = pcall(vim.api.nvim_buf_get_var, buf, "is_todo_buffer")
            if ok and is_todo then
                safe_close_win(vim.fn.bufwinid(buf))
                safe_delete_buf(buf)
                state.win, state.buf, state.origin_win = nil, nil, nil
                return
            end
        end
    end

    -- No TODO buffer, create new one
    local search = require("todo-list.search")
    local todos = search.scan()
    M.render(todos)
end

return M

