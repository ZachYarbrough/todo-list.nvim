local config = require("todo-list.config")

local M = {}

function M.scan(root)
    root = root or vim.fn.getcwd()
    local todos_by_file = {}

    local ignore_args = ""
    for _, pattern in ipairs(config.options.blacklist) do
        ignore_args = ignore_args .. string.format(' --glob "!%s"', pattern)
    end

    local cmd = string.format(
        'rg --vimgrep --glob "*.py" --glob "*.lua" --glob "*.js" --glob "*.ts" --glob "*.jsx" --glob "*.tsx" --glob "*.java"%s TODO "%s"',
        ignore_args,
        root
    )

    local handle = io.popen(cmd)
    if not handle then return todos_by_file end

    for line in handle:lines() do
        local filepath, lnum, _, text = line:match("^(.-):(%d+):(%d+):(.*)$")
        if filepath and lnum and text then
            local todo_text =
                text:match("(%s*#%s*TODO.*)") or
                text:match("(%s*//%s*TODO.*)") or
                text:match("(%s*%-%-%s*TODO.*)") or
                text:match("{/%*%s*TODO.-%*/}")

            if todo_text then
                todos_by_file[filepath] = todos_by_file[filepath] or {}
                local ext = filepath:match("%.([a-zA-Z0-9]+)$") or ""
                table.insert(todos_by_file[filepath], string.format("%s:%s: %s", ext, lnum, todo_text))
            end
        end
    end
    handle:close()

    return todos_by_file
end

return M

