local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

---@class public_module
local pub = {}

local plugin_dir

--- checks if the user is on windows
local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_linux = wezterm.target_triple == "x86_64-unknown-linux-gnu"
local separator = is_windows and "\\" or "/"

--- Checks if the plugin directory exists
--- @return boolean
local function directory_exists(path)
    local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
    return success and result
end

--- Returns the name of the package, used when requiring modules
--- @return string
function pub.get_require_path()
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
        .. pub.get_require_path()
        .. separator
        .. "plugin"
        .. separator
        .. "?.lua"
end

enable_sub_modules()

-- The directory where the plugin is installed
pub.save_state_dir = plugin_dir .. separator .. pub.get_require_path() .. separator .. "state" .. separator

--- Displays a notification in WezTerm.
-- @param message string: The notification message to be displayed.
local function display_notification(message)
    wezterm.log_info(message)
    -- Additional code to display a GUI notification can be added here if needed
end

--- Retrieves the current workspace data from the active window.
-- @param window wezterm.Window: The active window to retrieve the workspace data from.
-- @return table or nil: The workspace data table or nil if no active window is found.
local function retrieve_workspace_data(window)
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

--- Saves data to a JSON file.
-- @param data table: The workspace data to be saved.
-- @param file_path string: The file path where the JSON file will be saved.
-- @return boolean: true if saving was successful, false otherwise.
local function save_to_json_file(data, file_path)
    if not data then
        wezterm.log_info("No workspace data to log.")
        return false
    end

    local file = io.open(file_path, "w")
    if file then
        file:write(wezterm.json_encode(data))
        file:close()
        return true
    else
        return false
    end
end

--- Recreates the workspace based on the provided data.
-- @param workspace_data table: The data structure containing the saved workspace state.
local function recreate_workspace(window, workspace_data)
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

--- Loads data from a JSON file.
-- @param file_path string: The file path from which the JSON data will be loaded.
-- @return table or nil: The loaded data as a Lua table, or nil if loading failed.
local function load_from_json_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        wezterm.log_info("Failed to open file: " .. file_path)
        return nil
    end

    local file_content = file:read("*a")
    file:close()

    local data = wezterm.json_parse(file_content)
    if not data then
        wezterm.log_info("Failed to parse JSON data from file: " .. file_path)
    end
    return data
end

--- Restores a workspace name
function pub.restore_workspace(window, workspace_name)
    wezterm.log_info("Restoring state for workspace: " .. workspace_name)
    local file_path = pub.save_state_dir .. "wezterm_state_" .. workspace_name .. ".json"
    -- wezterm.log_error("WORKSPACE NAME" .. workspace_name)

    local workspace_data = load_from_json_file(file_path)
    if not workspace_data then
        window:toast_notification('WezTerm',
            'Workspace state file not found for workspace: ' .. workspace_name, nil, 4000)
        return
    end

    if recreate_workspace(window, workspace_data) then
        window:toast_notification('WezTerm', 'Workspace state loaded for workspace: ' .. workspace_name,
            nil, 4000)
    else
        window:toast_notification('WezTerm', 'Workspace state loading failed for workspace: ' .. workspace_name,
            nil, 4000)
    end
end

--- Loads the saved json file matching the current workspace.
function pub.restore_state(window)
    local workspace_name = window:active_workspace()
    pub.restore_workspace(window, workspace_name)
end

--- Returns the list of available workspaces
function pub.get_workspaces()
    local choices = {}
    for dir in io.popen("ls -pa " .. pub.save_state_dir .. " | grep -v /"):lines() do
        if string.find(dir, "wezterm_state_") then
            local w = dir:gsub("wezterm_state_", "")
            w = w:gsub(".json", "")
            table.insert(choices, { id = dir, label = w })
        end
    end
    return choices
end

--- Allows to select which workspace to load
function pub.load_state(window, pane)
    local choices = pub.get_workspaces()

    window:perform_action(
        act.InputSelector({
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
                if id and label then
                    wezterm.log_info("Current ws: " .. window:active_workspace() .. " - Selected ws: " .. label)
                    -- switch to workspace
                    window:perform_action(
                        act.SwitchToWorkspace {
                            name = label,
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
    local data = retrieve_workspace_data(window)

    -- Construct the file path based on the workspace name
    local file_path = pub.save_state_dir .. "wezterm_state_" .. data.name .. ".json"

    -- Save the workspace data to a JSON file and display the appropriate notification
    if save_to_json_file(data, file_path) then
        window:toast_notification('WezTerm Session Manager', 'Workspace state saved successfully', nil, 4000)
    else
        window:toast_notification('WezTerm Session Manager', 'Failed to save workspace state', nil, 4000)
    end
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
    }
    )
end

wezterm.on("save_session", function(window) pub.save_state(window) end)
wezterm.on("load_session", function(window, pane) pub.load_state(window, pane) end)
wezterm.on("restore_session", function(window) pub.restore_state(window) end)

return pub
