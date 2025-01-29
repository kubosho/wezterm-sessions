local wezterm = require("wezterm")
local fs = require('fs')
local win = require('window')

local ws = {}

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"

--- Retrieves the current workspace data from the active window.
-- @param window wezterm.Window: The active window to retrieve the workspace data from.
-- @return table or nil: The workspace data table or nil if no active window is found.
function ws.retrieve_workspace_data(window)
    local workspace_name = window:active_workspace()
    local workspace_data = {
        name = workspace_name,
        windows = {}
    }

    -- Iterale over windows
    for _, mux_win in ipairs(wezterm.mux.all_windows()) do
        if mux_win:get_workspace() == workspace_name then
            local win_data = {
                title = mux_win:get_title(),
                tabs = {}
            }

            -- Iterate over tabs in the current window
            for _, tab in ipairs(mux_win:tabs()) do
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

                table.insert(win_data.tabs, tab_data)
            end

            table.insert(workspace_data.windows, win_data)
        end
    end

    return workspace_data
end

--- Recreates the workspace based on the provided data.
-- @param workspace_data table: The data structure containing the saved workspace state.
function ws.recreate_workspace(window, workspace_name, workspace_data)
    if not workspace_data or not workspace_data.windows then
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

    -- Recreate windows tabs and panes from the saved state
    for idx, win_data in ipairs(workspace_data.windows) do
        if idx == 1 then
            win.restore_window(window, win_data)
        else
            local _, _, w = wezterm.mux.spawn_window({
                workspace = workspace_name,
            })
            win.restore_window(w:gui_window(), win_data)
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

    if ws.recreate_workspace(window, workspace_name, workspace_data) then
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
            table.insert(choices, { id = d, label = fs.unescape_file_name(w) })
        end
    end
    return choices
end

return ws
