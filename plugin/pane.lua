local wezterm = require("wezterm")
local fs = require('fs')
local p = {}

function p.restore_pane(window, tab, tab_data, j, pane_data)
    local new_pane
    if j == 1 then
        new_pane = tab:active_pane()
    else
        local direction = 'Right'
        -- TODO: manage size with more than two splits in same direction
        local size = pane_data.width / (tab_data.panes[j - 1].width + pane_data.width)
        if pane_data.left == tab_data.panes[j - 1].left then
            direction = 'Bottom'
            size = pane_data.height / (tab_data.panes[j - 1].height + pane_data.height)
        end

        wezterm.sleep_ms(100)
        new_pane = tab:active_pane():split({
            direction = direction,
            cwd = fs.extract_path_from_dir(pane_data.cwd),
            size = size
        })
    end

    if not new_pane then
        wezterm.log_info("Failed to create a new pane.")
        return
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

return p
