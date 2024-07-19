local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local config = require("projects.config")

local M = {}
local _projects = {}

local get_unsaved_buffers_total = function()
    local unsaved_buffers = 0

    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        local buffer_name = vim.api.nvim_buf_get_name(buffer)

        if buffer_name ~= "" and vim.api.nvim_buf_get_option(buffer, "modified") then
            unsaved_buffers = unsaved_buffers + 1
        end
    end

    return unsaved_buffers
end

local save_projects = function(data)
    local json = vim.fn.json_encode(data)

    vim.fn.writefile({ json }, config.get().projects_file)
end

local is_current_project = function(project)
    return project == vim.fn.getcwd()
end

local get_projects = function()
    local results = {}

    for _, project in ipairs(_projects) do
        local is_current = is_current_project(project)

        if is_current and config.get().hide_current_project then
            -- pass
        else
            local icon = is_current and " [ current]" or ""

            table.insert(results, project .. icon)
        end
    end

    print(vim.inspect(results))

    return results
end

M.show = function()
    local projects_list = get_projects()

    if #projects_list == 0 then
        vim.notify("  Your projects list is empty", "warn", { title = "Projects" })

        return
    end

    pickers.new({}, {
        prompt_title = "Projects",
        finder = finders.new_table {
            results = projects_list
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            local open_project = function()
                local selection = action_state.get_selected_entry(prompt_bufnr)

                if not selection then
                    return
                end

                local open_buffers = get_unsaved_buffers_total()

                if open_buffers > 0 then
                    vim.notify("  Cannot switch project as you have unsaved buffers", "warn",
                        { title = "Project not changed" })

                    return
                end

                local index = selection.index
                local project = _projects[index]

                if is_current_project(project) then
                    return
                end

                actions.close(prompt_bufnr)
                local auto_session = nil
                local ok = pcall(require, "auto-session")

                if ok then
                    auto_session = require("auto-session")
                    auto_session.SaveSession()
                end

                local folder = selection.value
                vim.cmd('cd ' .. folder)

                vim.defer_fn(function()
                    if auto_session then
                        auto_session.RestoreSession()
                    end

                    local all_buffers = vim.fn.getbufinfo({ buflisted = 1 })

                    for _, buffer in ipairs(all_buffers) do
                        local path = vim.fn.bufname(buffer.bufnr)
                        local first_char = string.sub(path, 1, 1)

                        if first_char == "/" then
                            vim.cmd("bdelete " .. buffer.bufnr)
                        end
                    end

                    vim.api.nvim_exec('doautocmd User ProjectOpened', false)
                end, 100)
            end

            local remove_project = function()
                local selection = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)

                for i, project in ipairs(projects_list) do
                    if project == selection.value then
                        table.remove(projects_list, i)
                        save_projects(projects_list)

                        vim.notify(" The project has been removed from your list", "info", { title = "Project removed" })
                        break
                    end
                end

                M.show()
            end

            map("i", "<CR>", open_project)
            map("n", "<CR>", open_project)
            map("i", "<C-x>", remove_project)

            return true
        end,
    }):find()
end

M.add = function(is_silent)
    local exists = false
    local current_path = vim.fn.getcwd()

    for _, project in ipairs(_projects) do
        if project == current_path then
            exists = true
            break
        end
    end

    if not exists then
        table.insert(_projects, current_path)
        save_projects(_projects)

        if not is_silent then
            vim.notify("  The project has been added to the list", nil, { title = "Project added" })
        end
    else
        if not is_silent then
            vim.notify("  The project already exists in your list", "warn", { title = "Project not added" })
        end
    end
end

M.is_project = function()
    local current_path = vim.fn.getcwd()

    for _, project in ipairs(_projects) do
        if project == current_path then
            return true
        end
    end

    return false
end

M.init = function()
    local projects_file = config.get().projects_file

    if vim.fn.filereadable(projects_file) == 1 then
        _projects = vim.fn.json_decode(vim.fn.readfile(vim.fn.expand(projects_file)))
    else
        save_projects(_projects)
    end

    if config.get().auto_add then
        M.add(true)
    end
end

return M
