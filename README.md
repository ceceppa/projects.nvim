# Projects.nvim

A simple project manager for Neovim.

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
        'rmagatti/auto-session' -- optional
    }
}
```

## Usage

- `:Projects` to open the project manager
- `:Project add` to add a new project

## Configuration

```lua
require('projects').setup {
    auto_add = true, -- auto add project root to projects.json
    close_unrelated_buffers = true, -- close all buffers that are not related to the project after opening it
    projects_file = '~/.config/nvim/projects.json', -- default
}
```

If you want to save and restore the current or previous session you can add the `auto-session` plugin as a dependency.
