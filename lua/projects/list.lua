local config        = require "projects.config"
local utils         = require "projects.utils"

local api           = vim.api

local _projects     = {}

local save_projects = function()
    local json = vim.fn.json_encode(_projects)

    vim.fn.writefile({ json }, config.get().projects_file)
end


local function load()
    local projects_file = config.get().projects_file

    if vim.fn.filereadable(projects_file) == 1 then
        _projects = vim.fn.json_decode(vim.fn.readfile(vim.fn.expand(projects_file)))
    else
        save_projects()
    end
end

local function add_project(is_silent)
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
        save_projects()

        if not is_silent then
            vim.notify("  The project has been added to the list", nil, { title = "Project added" })
        end
    else
        if not is_silent then
            vim.notify("  The project already exists in your list", "warn", { title = "Project not added" })
        end
    end
end

local get_projects = function()
    local results = {}

    for _, project in ipairs(_projects) do
        local is_current = utils.is_current_project(project)

        if is_current and config.get().hide_current_project then
            -- pass
        else
            local icon = is_current and " [  current]" or ""
            project = utils.abbreviate_path(project)

            table.insert(results, project .. icon)
        end
    end

    return results
end

local function remove_project(project_path)
    for i, project in ipairs(_projects) do
        if project == project_path then
            table.remove(_projects, i)
            save_projects()

            vim.notify(" The project has been removed from your list", "info", { title = "Project removed" })
            break
        end
    end
end

local function create_popup(projects)
    local buf = api.nvim_create_buf(false, true)

    api.nvim_buf_set_lines(buf, 0, -1, false, projects)

    -- Calculate dimensions and position
    local width = 60
    local height = #projects + 2 -- Add 2 for header and footer
    local win_height = api.nvim_get_option("lines")
    local win_width = api.nvim_get_option("columns")
    local row = math.floor((win_height - height) / 2)
    local col = math.floor((win_width - width) / 2)

    -- Set window options
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded"
    }

    local win = api.nvim_open_win(buf, true, opts)

    api.nvim_buf_set_option(buf, "modifiable", false)
    api.nvim_buf_set_option(buf, "buftype", "nofile")
    api.nvim_win_set_option(win, "cursorline", true)

    local function close_window()
        api.nvim_win_close(win, true)
    end

    local function select_project()
        local line_num = api.nvim_win_get_cursor(win)[1]
        local selected_project = projects[line_num]
        close_window()

        utils.change_directory(selected_project)
    end

    local function remove_selected_project()
        local line_num = api.nvim_win_get_cursor(win)[1]
        local selected_project = projects[line_num]

        remove_project(selected_project)
        close_window()
        create_popup(get_projects())
    end

    api.nvim_buf_set_keymap(buf, 'n', 'q', '', { callback = close_window, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<ESC>', '', { callback = close_window, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', { callback = select_project, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<C-x>', '', { callback = remove_selected_project, noremap = true, silent = true })

    api.nvim_buf_set_option(buf, "filetype", "projectlist")

    vim.cmd([[
        syntax match ProjectPath /.*$/
        highlight ProjectPath ctermfg=white guifg=white
    ]])

    api.nvim_win_set_cursor(win, { 1, 0 })
end

local function telescope_list(projects_list, show)
    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local conf = require("telescope.config").values
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"

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

                utils.change_directory(selection.value)

                actions.close(prompt_bufnr)
            end

            local remove_selected_project = function()
                local selection = action_state.get_selected_entry(prompt_bufnr)
                actions.close(prompt_bufnr)

                if not selection then
                    return
                end

                remove_project(selection.value)

                show()
            end

            map("i", "<CR>", open_project)
            map("n", "<CR>", open_project)
            map("i", "<C-x>", remove_selected_project)

            return true
        end,
    }):find()
end

local function is_telescope_available()
    local has_telescope = pcall(require, "telescope")
    local pickers = pcall(require, "telescope.pickers")
    local finders = pcall(require, "telescope.finders")
    local conf = pcall(require, "telescope.config")
    local actions = pcall(require, "telescope.actions")
    local action_state = pcall(require, "telescope.actions.state")
    return has_telescope and pickers and finders and conf and actions and action_state
end

local function show()
    local projects_list = get_projects()

    if #projects_list == 0 then
        vim.notify("  Your projects list is empty", "warn", { title = "Projects" })

        return
    end

    if is_telescope_available() then
        telescope_list(projects_list, show)
        return
    end

    create_popup(projects_list)
end

return {
    show = show,
    add = add_project,
    get = get_projects,
    load = load
}
