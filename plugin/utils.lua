local wezterm = require("wezterm")
local utils = {}

--- Checks if the user is on Windows
function utils.is_windows()
    return wezterm.target_triple:find("windows") ~= nil
end

--- Displays a notification with the specified message.
function utils.notify(window, message)
    return window:toast_notification('WezTerm', message, nil, 2000)
end

return utils
