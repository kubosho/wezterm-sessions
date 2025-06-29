local wezterm = require("wezterm")

local utils = {}

function utils.is_windows()
  return wezterm.target_triple:find("windows") ~= nil
end

--- Displays a notification with the specified message based on configuration.
--- @param window wezterm.Window: The window to display the notification in
--- @param message string: The message to display
--- @param config table: Optional configuration table with notification_method and notification_duration
function utils.notify(window, message, config)
  local method = config and config.notification_method or "toast"
  local duration = config and config.notification_duration or 2000

  if method == "toast" or method == "both" then
    window:toast_notification("WezTerm Sessions", message, nil, duration)
  end

  if method == "log" or method == "both" then
    wezterm.log_info("[WezTerm Sessions] " .. message)
  end
end

return utils
