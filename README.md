# Projects.nvim

A simple project manager for Neovim.

## Features

- Switch between projects
- Updates terminal cwd on project change

## Installation

Use your favorite plugin manager to install this plugin. For example:

Packer:

```
use {
    'ceceppa/projects.nvim',
    config = function()
        require('projects').setup()
    end,
    requires = {
        'nvim-telescope/telescope.nvim', -- optional
        'nvim-telescope/telescope-ui-select.nvim', -- optional
        'rmagatti/auto-session' -- optional,
    }
}
```

## Usage

- `:Projects` to open the project manager
- `:Project add` to add a new project
- Projects List: `<C-x>` to delete a project from list

## Configuration

```lua
require('projects').setup {
    auto_add = true, -- auto add project root to projects.json
    close_unrelated_buffers = true, -- close all buffers that are not related to the project after opening it
    projects_file = '~/.config/nvim/projects.json', -- default
    hide_current_project = false, -- hide the current project in the project list
    abbreviate_home = true, -- abbreviate home directory in project list
}
```

If you want to save and restore the current or previous session you can add the `auto-session` plugin as a dependency.

## Events

```
vim.api.nvim_create_autocmd("User", {
    pattern = "ProjectOpened",
    callback = function()
        print("ProjectOpened")
    end,
})
```
