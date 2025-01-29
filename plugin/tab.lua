local wezterm = require("wezterm")
local fs = require('fs')
local p = require('pane')
local t = {}

function t.restore_tab(window, tab_data)
    local cwd_uri = tab_data.panes[1].cwd
    local cwd_path = fs.extract_path_from_dir(cwd_uri)

    local new_tab = window:mux_window():spawn_tab({ cwd = cwd_path })
    if not new_tab then
        wezterm.log_info("Failed to create a new tab.")
        return
    end

    -- Activate the new tab before creating panes
    new_tab:activate()

    -- Recreate panes within this tab
    for j, pane_data in ipairs(tab_data.panes) do
        p.restore_pane(window, new_tab, tab_data, j, pane_data)
    end
end

return t
