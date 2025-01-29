local wezterm = require("wezterm")
local t = require('tab')
local pub = {}

function pub.retrieve_window_data(mux_window)
    local win_data = {
        title = mux_window:get_title(),
        tabs = {}
    }

    -- Iterate over tabs in the current window
    for _, tab in ipairs(mux_window:tabs()) do
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

    return win_data
end

function pub.restore_window(window, win_data)
    local initial_pane = window:active_pane()
    local foreground_process = initial_pane:get_foreground_process_name()

    -- Check if the foreground process is a shell
    if foreground_process then
        if foreground_process:find("sh") or
            foreground_process:find("cmd.exe") or
            foreground_process:find("powershell.exe") or
            foreground_process:find("pwsh.exe") or
            foreground_process:find("nu") or
            foreground_process:find("zsh") then
            -- Safe to close
            initial_pane:send_text("exit\r")
        else
            wezterm.log_info("Active program detected. Skipping exit command for initial pane.")
        end
    else
        -- Safe to close
        initial_pane:send_text("exit\r")
    end

    for _, tab_data in ipairs(win_data.tabs) do
        t.restore_tab(window, tab_data)
    end
end

return pub
