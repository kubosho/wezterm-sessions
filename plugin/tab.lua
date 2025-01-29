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
