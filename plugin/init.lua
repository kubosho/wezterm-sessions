local wezterm = require("wezterm")
local act = wezterm.action

---@class public_module
local pub = {}

local plugin_dir

--- checks if the user is on windows
local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local separator = is_windows and "\\" or "/"

--- Checks if the plugin directory exists
--- @return boolean
local function directory_exists(path)
    local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
    return success and result
end

--- Returns the name of the package, used when requiring modules
--- @return string
local function get_require_path()
    local path1 = "httpssCssZssZsgithubsDscomsZsabidibosZswezterm-sessions"
    local path2 = "httpssCssZssZsgithubsDscomsZsabidibosZswezterm-sessionsZs"
    return directory_exists(path2) and path2 or path1
end

--- adds the wezterm plugin directory to the lua path
local function enable_sub_modules()
    plugin_dir = wezterm.plugin.list()[1].plugin_dir:gsub(separator .. "[^" .. separator .. "]*$", "")
    package.path = package.path
        .. ";"
        .. plugin_dir
        .. separator
        .. get_require_path()
        .. separator
        .. "plugin"
        .. separator
        .. "?.lua"
end

enable_sub_modules()

local ws = require("workspace")
local fs = require("fs")

-- The directory where we store the workspaces state
local save_state_dir = plugin_dir .. separator .. get_require_path() .. separator .. "state" .. separator

--- Loads the saved json file matching the current workspace.
function pub.restore_state(window)
    local workspace_name = window:active_workspace()
    ws.restore_workspace(window, save_state_dir, workspace_name)
end


--- Allows to select which workspace to load
function pub.load_state(window, pane)
    local choices = ws.get_workspaces(save_state_dir)

    window:perform_action(
        act.InputSelector({
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
                if id and label then
                    wezterm.log_info("Switching to ws: " .. label)
                    -- switch to workspace
                    window:perform_action(
                        act.SwitchToWorkspace {
                            name = fs.unescape_file_name(label),
                        },
                        inner_pane
                    )
                    wezterm.sleep_ms(2000)
                    window:perform_action(
                        act.EmitEvent 'wezter-sessions-switch',
                        pane
                    )
                end
            end),
            title = "Choose Workspace",
            description = "Select a workspace and press Enter = accept, Esc = cancel, / = filter",
            fuzzy_description = "Workspace to switch: ",
            choices = choices,
            fuzzy = true,
        }),
        pane
    )
end

wezterm.on("wezter-sessions-switch", function(window, pane)
    pub.restore_state(window)
end)

--- Orchestrator function to save the current workspace state.
-- Collects workspace data, saves it to a JSON file, and displays a notification.
function pub.save_state(window)
    local data = ws.retrieve_workspace_data(window)

    -- Construct the file path based on the workspace name
    local file_path = save_state_dir .. "wezterm_state_" .. fs.escape_file_name(data.name) .. ".json"

    -- Save the workspace data to a JSON file and display the appropriate notification
    if fs.save_to_json_file(data, file_path) then
        window:toast_notification('WezTerm Sessions', 'Workspace state saved successfully', nil, 4000)
    else
        window:toast_notification('WezTerm Sessions', 'Failed to save workspace state', nil, 4000)
    end
end

--- Allows to select which workspace to delete
function pub.delete_state(window, pane)
    local choices = ws.get_workspaces(save_state_dir)

    window:perform_action(
        act.InputSelector({
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
                if id and label then
                    wezterm.log_info("Deleting ws: " .. label)
                    local file_path = save_state_dir .. "wezterm_state_" .. label .. ".json"
                    if fs.delete_json_file(file_path) then
                        window:toast_notification('WezTerm Sessions', 'Workspace state deleted successfully', nil, 4000)
                    else
                        window:toast_notification('WezTerm Sessions', 'Failed to delete workspace state', nil, 4000)
                    end
                end
            end),
            title = "Choose Workspace to delete",
            description = "Select a workspace and press Enter = accept, Esc = cancel, / = filter",
            fuzzy_description = "Workspace to delete: ",
            choices = choices,
            fuzzy = true,
        }),
        pane
    )
end

---sets default keybindings
function pub.apply_to_config(config)
    if config == nil then
        config = {}
    end

    if config.keys == nil then
        config.keys = {}
    end

    table.insert(config.keys, {
        key = 's',
        mods = 'ALT',
        action = act({ EmitEvent = "save_session" }),
    })
    table.insert(config.keys, {
        key = 'l',
        mods = 'ALT',
        action = act({ EmitEvent = "load_session" }),
    })
    table.insert(config.keys, {
        key = 'r',
        mods = 'ALT',
        action = act({ EmitEvent = "restore_session" }),
    })
    table.insert(config.keys, {
        key = 'd',
        mods = 'CTRL|SHIFT',
        action = act({ EmitEvent = "delete_session" }),
    })
end

wezterm.on("save_session", function(window) pub.save_state(window) end)
wezterm.on("load_session", function(window, pane) pub.load_state(window, pane) end)
wezterm.on("restore_session", function(window) pub.restore_state(window) end)
wezterm.on("delete_session", function(window, pane) pub.delete_state(window, pane) end)

return pub
