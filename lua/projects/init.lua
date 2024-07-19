local config = require('projects.config')
local module = require('projects.module')

local setup = function(opts)
    config.set(opts)

    module.init()
end

vim.api.nvim_create_user_command("Projects", function(arguments)
    local action = arguments.fargs[1]

    if action == 'add' then
        module.add()
    elseif action == nil then
        module.show()
    else
        vim.notify('Invalid action', 'error', { title = 'Projects' })
    end
end, { desc = 'Projects', nargs = '*' })

return {
    show = module.show,
    add = module.add,
    is_project = module.is_project,
    setup = setup
}
