# 📝 Todo List
Organize and navigate all TODOs directly from the source code, in a floating, read-only buffer. Highlights each TODO with its file, line number, and supports multiple languages. Jump directly to TODO locations with ease.

<video autoplay loop muted playsinline width="600">
  <source src="https://github.com/ZachYarbrough/todo-list.nvim/raw/assets/todo-list-demo.mp4" type="video/mp4">
</video>

### Features:
- Floating window showing all project TODO comments.
- Supports multiple languages and comment styles (Python, Lua, JS/TS, Java, C, and more).
- Jump directly to TODOs with a single keypress.
- Lightweight, read-only buffer that does not modify files.
- Configurable key mappings and ignored directories.

### Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
require("lazy").setup({
    {
        "ZachYarbrough/todo-list.nvim",
        opts = {
            -- See the Configuration section below for a list of options
        },
    }
})
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    "ZachYarbrough/todo-list.nvim",
    opts = {
        -- See the Configuration section below for a list of options
    }
}
```
### [vim-plug](https://github.com/junegunn/vim-plug)
```lua
Plug 'ZachYarbrough/todo-list.nvim'

lua << EOF
require("todo-list.config").setup({
    -- See the Configuration section below for a list of options
})
EOF
```

### Configuration
| Option            | Default           | Description                                                                                |
|------------------|-----------------|----------------------------------------------------------------------------------------------|
| `blacklist`       | See defaults     | List of glob patterns to ignore when scanning for TODOs                                     |
| `line_number_mode`| `"none"`         | `"none"` → no numbers>br> `"absolute"` → absolute numbers only<br> `"relative"` → relative numbers (current line absolute) |
| `padding_left`    | `2`              | Number of spaces to add to the left of each line in the floating window                     |
| `cursorline`      | `true`           | Highlight the current line in the floating window                                           |
| `cursorline_bg`   | theme CursorLine | Background color for the cursor line. Defaults to the user’s theme CursorLine color if `nil` |

### Usage
`<C-t>` toggles the floating window<br>
`<CR>` closes the window and opens the file at the TODO’s line.<br>
`<Esc>` or `q` close the window
#### Example Keymap
```lua
-- Toggle TODO list floating window
vim.keymap.set("n", "<leader>td", function()
    require("todo-list").toggle()
end)
```
