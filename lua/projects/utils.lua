local config = require("projects.config")

local current_session_has_unsaved_buffers = function()
    local unsaved_buffers = 0

    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        local buffer_name = vim.api.nvim_buf_get_name(buffer)

        if buffer_name ~= "" and vim.api.nvim_buf_get_option(buffer, "modified") then
            unsaved_buffers = unsaved_buffers + 1
        end
    end

    return unsaved_buffers > 0
end

local function close_unrelated_buffers()
    if not config.get().close_unrelated_buffers then
        return
    end

    local all_buffers = vim.fn.getbufinfo({ buflisted = 1 })

    for _, buffer in ipairs(all_buffers) do
        local path = vim.fn.bufname(buffer.bufnr)
        local first_char = string.sub(path, 1, 1)
        if first_char == "/" then
            vim.cmd("bdelete " .. buffer.bufnr)
        end
    end
end

local is_current_project = function(project)
    return project == vim.fn.getcwd()
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
    new_path = new_path:gsub(" %[  current%]$", "")

    if current_session_has_unsaved_buffers() then
        vim.notify("  Cannot switch project as you have unsaved buffers", "warn",
            { title = "Project not changed" })

        return
    end

    if is_current_project(new_path) then
        return
    end

    new_path = vim.fn.expand(new_path)
    local is_valid_path = vim.fn.isdirectory(new_path) == 1

    if not is_valid_path then
        vim.notify("Invalid path: " .. new_path, "error", { title = "Error" })

        return false
    end

    local auto_session = nil
    local ok = pcall(require, "auto-session")

    if ok then
        auto_session = require("auto-session")
        auto_session.SaveSession()
    end

    change_directory_and_update_terminal(new_path)

    if config.get().notify_on_project_change then
        vim.notify("  Project changed to " .. abbreviate_path(new_path), nil, { title = "Projects" })
    end

    vim.defer_fn(function()
        if auto_session then
            auto_session.RestoreSession()
        end

        vim.defer_fn(function()
            close_unrelated_buffers()
        end, 100)

        vim.api.nvim_exec('doautocmd User ProjectOpened', false)
    end, 100)

    return true
end

local is_git_project = function()
    local dir = vim.fn.getcwd()
    local git_dir = dir .. "/.git"

    return vim.fn.isdirectory(git_dir) == 1
end



return {
    is_current_project = is_current_project,
    abbreviate_path = abbreviate_path,
    change_directory = change_directory,
    is_git_project = is_git_project
}
