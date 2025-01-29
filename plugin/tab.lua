local wezterm = require("wezterm")
local fs = require('fs')
local p = require('pane')
local pub = {}

--- Retrieves tab data
-- @param tab wezterm.Tab: The tab to retrieve data from.
-- @return table: The tab data table.
function pub.retrieve_tab_data(tab)
    local tab_data = {
        tab_id = tostring(tab:tab_id()),
        panes = {}
    }

    -- Iterate over panes in the current tab
    for _, pane_info in ipairs(tab:panes_with_info()) do
        -- Collect pane details, including layout and process information
        local pane_data = p.retrieve_pane_data(pane_info)
        table.insert(tab_data.panes, pane_data)
    end

    return tab_data
end

function pub.restore_tab(window, tab_data)
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

return pub
