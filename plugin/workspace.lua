local wezterm = require("wezterm")
local fs = require('fs')

local  ws = {}

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_linux = wezterm.target_triple == "x86_64-unknown-linux-gnu"

--- Retrieves the current workspace data from the active window.
-- @param window wezterm.Window: The active window to retrieve the workspace data from.
-- @return table or nil: The workspace data table or nil if no active window is found.
function ws.retrieve_workspace_data(window)
    local workspace_name = window:active_workspace()
    local workspace_data = {
        name = workspace_name,
        tabs = {}
    }

    -- Iterate over tabs in the current window
    for _, tab in ipairs(window:mux_window():tabs()) do
        local tab_data = {
            tab_id = tostring(tab:tab_id()),
            panes = {}
        }

        -- Iterate over panes in the current tab
        for _, pane_info in ipairs(tab:panes_with_info()) do
            -- Collect pane details, including layout and process information
            table.insert(tab_data.panes, {
                pane_id = tostring(pane_info.pane:pane_id()),
                index = pane_info.index,
                is_active = pane_info.is_active,
                is_zoomed = pane_info.is_zoomed,
                left = pane_info.left,
                top = pane_info.top,
                width = pane_info.width,
                height = pane_info.height,
                pixel_width = pane_info.pixel_width,
                pixel_height = pane_info.pixel_height,
                cwd = tostring(pane_info.pane:get_current_working_dir()),
                tty = tostring(pane_info.pane:get_foreground_process_name())
            })
        end

        table.insert(workspace_data.tabs, tab_data)
    end

    return workspace_data
end


--- Recreates the workspace based on the provided data.
-- @param workspace_data table: The data structure containing the saved workspace state.
function ws.recreate_workspace(window, workspace_data)
    local function extract_path_from_dir(working_directory)
        if is_windows then
            -- On Windows, transform 'file:///C:/path/to/dir' to 'C:/path/to/dir'
            return working_directory:gsub("file:///", "")
        elseif is_linux then
            -- On Linux, transform 'file://{computer-name}/home/{user}/path/to/dir' to '/home/{user}/path/to/dir'
            return working_directory:gsub("^.*(/home/)", "/home/")
        else
            return working_directory:gsub("^.*(/Users/)", "/Users/")
        end
    end

    if not workspace_data or not workspace_data.tabs then
        wezterm.log_info("Invalid or empty workspace data provided.")
        return
    end

    local tabs = window:mux_window():tabs()

    if #tabs ~= 1 or #tabs[1]:panes() ~= 1 then
        wezterm.log_info(
            "Restoration can only be performed in a window with a single tab and a single pane, to prevent accidental data loss.")
        return
    end

    local initial_pane = window:active_pane()
    local foreground_process = initial_pane:get_foreground_process_name()

    -- Check if the foreground process is a shell
    if foreground_process then
        if foreground_process:find("sh") or foreground_process:find("cmd.exe") or foreground_process:find("powershell.exe") or foreground_process:find("pwsh.exe") or foreground_process:find("nu") or foreground_process:find("zsh") then
            -- Safe to close
            initial_pane:send_text("exit\r")
        else
            wezterm.log_info("Active program detected. Skipping exit command for initial pane.")
        end
    else
        -- Safe to close
        initial_pane:send_text("exit\r")
    end

    -- Recreate tabs and panes from the saved state
    for _, tab_data in ipairs(workspace_data.tabs) do
        local cwd_uri = tab_data.panes[1].cwd
        local cwd_path = extract_path_from_dir(cwd_uri)

        local new_tab = window:mux_window():spawn_tab({ cwd = cwd_path })
        if not new_tab then
            wezterm.log_info("Failed to create a new tab.")
            break
        end

        -- Activate the new tab before creating panes
        new_tab:activate()

        -- Recreate panes within this tab
        for j, pane_data in ipairs(tab_data.panes) do
            local new_pane
            if j == 1 then
                new_pane = new_tab:active_pane()
            else
                local direction = 'Right'
                -- TODO: manage size with more than two splits in same direction
                local size = pane_data.width / (tab_data.panes[j - 1].width + pane_data.width)
                if pane_data.left == tab_data.panes[j - 1].left then
                    direction = 'Bottom'
                    size = pane_data.height / (tab_data.panes[j - 1].height + pane_data.height)
                end

                new_pane = new_tab:active_pane():split({
                    direction = direction,
                    cwd = extract_path_from_dir(pane_data.cwd),
                    size = size
                })
            end

            if not new_pane then
                wezterm.log_info("Failed to create a new pane.")
                break
            end

            -- Restore TTY for Neovim on Linux
            -- NOTE: cwd is handled differently on windows. maybe extend functionality for windows later
            -- This could probably be handled better in general
            if not (is_windows) then
                if pane_data.tty:sub(- #"/bin/nvim") == "/bin/nvim" then
                    new_pane:send_text(pane_data.tty .. " ." .. "\n")
                elseif pane_data.tty ~= "nil" then
                    -- TODO - With running npm commands (e.g a running web client) this seems to execute Node, without the arguments
                    new_pane:send_text(pane_data.tty .. "\n")
                end
            end
        end
    end

    wezterm.log_info("Workspace recreated with new tabs and panes based on saved state.")
    return true
end

--- Restores a workspace name
function ws.restore_workspace(window, dir, workspace_name)
    wezterm.log_info("Restoring state for workspace: " .. workspace_name)
    local file_path = dir .. "wezterm_state_" .. fs.escape_file_name(workspace_name) .. ".json"

    local workspace_data = fs.load_from_json_file(file_path)
    if not workspace_data then
        window:toast_notification('WezTerm',
            'Workspace state file not found for workspace: ' .. workspace_name, nil, 4000)
        return
    end

    if ws.recreate_workspace(window, workspace_data) then
        window:toast_notification('WezTerm', 'Workspace state loaded for workspace: ' .. workspace_name,
            nil, 4000)
    else
        window:toast_notification('WezTerm', 'Workspace state loading failed for workspace: ' .. workspace_name,
            nil, 4000)
    end
end

--- Returns the list of available workspaces
--- @param dir string
--- @return table
function ws.get_workspaces(dir)
    local choices = {}
    for d in io.popen("ls -pa " .. dir .. " | grep -v /"):lines() do
        if string.find(d, "wezterm_state_") then
            local w = d:gsub("wezterm_state_", "")
            w = w:gsub(".json", "")
            table.insert(choices, { id = d, label = w })
        end
    end
    return choices
end

return ws
