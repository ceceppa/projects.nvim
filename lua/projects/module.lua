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

local is_git_project = function()
    local dir = vim.fn.getcwd()
    local git_dir = dir .. "/.git"

    return vim.fn.isdirectory(git_dir) == 1
end

local function abbreviate_path(path)
    if config.get().abbreviate_home == false then
        return path
    end

    local full_path = vim.fn.expand(path)
    local home = vim.fn.expand('~')

    if vim.startswith(full_path, home) then
        path = '~' .. string.sub(full_path, #home + 1)
    end

    return path
end

local function change_directory_and_update_terminal(path)
    path = vim.fn.expand(path)
    vim.api.nvim_set_current_dir(path)

    path = abbreviate_path(path)
    local escaped_path = path:gsub("'", "'\\''")

    -- OSC 7 escape sequence to inform the terminal of the new working directory
    local osc7 = string.format('\027]7;file://%s%s\027\\', vim.loop.os_uname().sysname == "Darwin" and "localhost" or "",
        escaped_path)

    -- OSC 1 escape sequence to set the terminal's icon (tab) title
    local osc1 = string.format('\027]1;%s\027\\', vim.fn.fnamemodify(path, ':t'))

    -- OSC 2 escape sequence to set the terminal's window title
    local osc2 = string.format('\027]2;%s\027\\', path)

    -- Send the escape sequences to the terminal
    io.stdout:write(osc7)
    io.stdout:write(osc1)
    io.stdout:write(osc2)

    io.stdout:flush()
end

local function change_directory(new_path)
    local is_valid_path = vim.fn.isdirectory(new_path) == 1
    if not is_valid_path then
        vim.notify("Invalid path: " .. new_path, "error", { title = "Error" })

        return
    end

    change_directory_and_update_terminal(new_path)
end

local get_projects = function()
    local results = {}

    for _, project in ipairs(_projects) do
        local is_current = is_current_project(project)

        if is_current and config.get().hide_current_project then
            -- pass
        else
            local icon = is_current and " [  current]" or ""
            project = abbreviate_path(project)

            table.insert(results, project .. icon)
        end
    end

    return results
end

local function close_unrelated_buffers()
    local all_buffers = vim.fn.getbufinfo({ buflisted = 1 })

    for _, buffer in ipairs(all_buffers) do
        local path = vim.fn.bufname(buffer.bufnr)
        local first_char = string.sub(path, 1, 1)
        if first_char == "/" then
            vim.cmd("bdelete " .. buffer.bufnr)
        end
    end
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

                actions.close(prompt_bufnr)

                local index = selection.index
                local project = _projects[index]

                if is_current_project(project) then
                    return
                end

                local auto_session = nil
                local ok = pcall(require, "auto-session")

                if ok then
                    auto_session = require("auto-session")
                    auto_session.SaveSession()
                end

                local folder = selection.value
                change_directory(folder)

                vim.defer_fn(function()
                    if auto_session then
                        auto_session.RestoreSession()
                    end

                    vim.defer_fn(close_unrelated_buffers, 100)
                    vim.api.nvim_exec('doautocmd User ProjectOpened', false)
                end, 100)
            end

            local remove_project = function()
                local selection = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)

                for i, project in ipairs(_projects) do
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

    if config.get().auto_add == "none" then
        return
    elseif config.get().auto_add == "git" and is_git_project() then
        M.add(true)
    elseif config.get().auto_add == "all" then
        M.add(true)
    end
end

return M
