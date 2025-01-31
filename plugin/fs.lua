local wezterm = require("wezterm")
local fs = {}

--- checks if the user is on windows
local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local is_linux = wezterm.target_triple == "x86_64-unknown-linux-gnu"
local separator = is_windows and "\\" or "/"

--- Saves data to a JSON file.
-- @param data table: The workspace data to be saved.
-- @param file_path string: The file path where the JSON file will be saved.
-- @return boolean: true if saving was successful, false otherwise.
function fs.save_to_json_file(data, file_path)
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

--- Loads data from a JSON file.
-- @param file_path string: The file path from which the JSON data will be loaded.
-- @return table or nil: The loaded data as a Lua table, or nil if loading failed.
function fs.load_from_json_file(file_path)
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

--- Deletes the JSON file.
-- @param file_path string: The file path of the JSON file to be deleted.
-- @return boolean: true if deletion was successful, false otherwise.
function fs.delete_json_file(file_path)
    return os.remove(file_path)
end

--- Returns the escaped file name: os separator must be escaped if using it in the file name
--- @param file_name string
--- @return string
function fs.escape_file_name(file_name)
    local s = file_name:gsub(separator, "+")
    return s
end

--- Returns the unescaped file name
--- @param file_name string
--- @return string
function fs.unescape_file_name(file_name)
    local s = file_name:gsub("+", separator)
    return s
end

--- Retrieve the path from the working directory
--- @param working_directory string
--- @return string, number
function fs.extract_path_from_dir(working_directory)
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

return fs
