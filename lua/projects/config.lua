local config = {}
local NVIM_PROJECTS_FILE = vim.fn.stdpath('config') .. '/' .. 'projects.json'

--- @class Opts
--- @field auto_add string - 'all' | 'git' | 'none' (git) Add the current project to the list of projects when the plugin is loaded. 'all' adds all projects, 'git' adds only git projects, 'none' does not add any project
--- @field close_unrelated_buffers boolean - (true) When opening a project via the picker, closes all buffers that are not related to the new project
--- @field projects_file string - ([nvim config]/projects.json) The file where the list of projects is stored
--- @field hide_current_project boolean - (false) Hide the current project from the list of projects
--- @field abbreviate_home boolean - (true) Abbreviate the home directory in the project list
--- @field notify_on_project_change boolean - (true) Show a notification when the project is changed

local DEFAULT_CONFIG = {
    auto_add = 'git',
    close_unrelated_buffers = true,
    projects_file = NVIM_PROJECTS_FILE,
    hide_current_project = true,
    abbreviate_home = true,
    notify_on_project_change = true,
}

local function set(opts)
    config = vim.tbl_deep_extend("force", config, DEFAULT_CONFIG, opts or {})
end

local function get()
    return config
end

return {
    set = set,
    get = get
}
