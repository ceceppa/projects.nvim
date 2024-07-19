local config = {}
local NVIM_PROJECTS_FILE = vim.fn.stdpath('config') .. '/' .. 'projects.json'

--- @class Opts
--- @field auto_add boolean - (true) Automatically add the current project to the list of projects
--- @field close_unrelated_buffers boolean - (true) When opening a project via the picker, closes all buffers that are not related to the new project
--- @field projects_file string - ([nvim config]/projects.json) The file where the list of projects is stored 
--- @field hide_current_project boolean - (false) Hide the current project from the list of projects

local DEFAULT_CONFIG = {
    auto_add = true,
    close_unrelated_buffers = true,
    projects_file = NVIM_PROJECTS_FILE,
    hide_current_project = false
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

