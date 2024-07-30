local config = require('projects.config')
local list = require('projects.list')
local utils = require('projects.utils')

local setup = function(opts)
    config.set(opts)

    list.load()

    local should_add = config.get().auto_add == "all" or (config.get().auto_add == "git" and utils.is_git_project())

    if not should_add then
        return
    else
        list.add(true)
    end
end

local function is_project()
    local current_path = vim.fn.getcwd()

    for _, project in ipairs(list.get()) do
        if project == current_path then
            return true
        end
    end

    return false
end

vim.api.nvim_create_user_command("Projects", function(arguments)
    local action = arguments.fargs[1]

    if action == 'add' then
        list.add()
    elseif action == nil then
        list.show()
    else
        vim.notify('Invalid action', 'error', { title = 'Projects' })
    end
end, { desc = 'Projects', nargs = '*' })

return {
    show = list.show,
    add = list.add,
    is_project = is_project,
    setup = setup
}
