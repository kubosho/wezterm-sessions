local wezterm = require("wezterm")
local fs = require('fs')
local win = {}

function win.restore_window(window, win_data)
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

    for _, tab_data in ipairs(win_data.tabs) do
        local cwd_uri = tab_data.panes[1].cwd
        local cwd_path = fs.extract_path_from_dir(cwd_uri)

        wezterm.log_info("WNDOW", window)
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

                wezterm.sleep_ms(100)
                new_pane = new_tab:active_pane():split({
                    direction = direction,
                    cwd = fs.extract_path_from_dir(pane_data.cwd),
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
            if not (fs.is_windows) then
                if pane_data.tty:sub(- #"/bin/nvim") == "/bin/nvim" then
                    new_pane:send_text(pane_data.tty .. "\n")
                elseif pane_data.tty ~= "nil" then
                    -- TODO - With running npm commands (e.g a running web client) this seems to execute Node, without the arguments
                    new_pane:send_text(pane_data.tty .. "\n")
                end
            end
        end
    end
end

return win
