# WezTerm Session Manager

The [WezTerm](https://wezfurlong.org/wezterm/) Session Manager is a Lua script
enhancement for WezTerm that provides functionality to save, load, and restore
terminal sessions. This tool helps manage terminal sessions, its goal is to save
and restore different sessions or better workspaces and later restore them.

## Features

- **Save Session State** Captures the current layout of windows, tabs and panes,
  along with their working directories and foreground processes.
- **restore Session** Reopens a previously saved session that matches the
  current workspace name, restoring its layout and directories.
- **Load Session (Not implemented yet)** Allows selecting which saved session to
  load, regardless of the current workspace name.

## Installation

1. **Add to your wezterm config**

   ```lua
    local sessions = wezterm.plugin.require("https://github.com/abidibo/wezterm-sessions")
    sessions.apply_to_config(config) -- optional, this adds default keybindings
   ```

## Configuration

2. **Event Bindings:** You can define your own or keybindings:

    ```lua
    -- there are the default ones
    config.keys = {
        {
            key = 's',
            mods = 'CTRL|SHIFT',
            action = act({ EmitEvent = "save_session" }),
        },
        {
            key = 'l',
            mods = 'CTRL|SHIFT',
            action = act({ EmitEvent = "load_session" }),
        },
        {
            key = 'r',
            mods = 'CTRL|SHIFT',
            action = act({ EmitEvent = "restore_session" }),
        },
    }
   ```

3. I also recommend to set up a keybinding for creating **named** workspaces or rename the current one:

    ````lua 
    -- Rename current workspace
    {
        key = '$',
        mods = 'CTRL|SHIFT',
        action = act.PromptInputLine {
            description = 'Enter new workspace name',
            action = wezterm.action_callback(
                function(window, pane, line)
                    if line then
                        wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
                    end
                end
            ),
        },
    },
    ```
   

## Limitations

There are currently some limitations and improvements that need to be
implemented:

- The script does not restore the state of running applications within each pane
  (except nvim on linux which seems to work fine but the general handling should
  be improved)
- It' primarily tested on Linux and Windows, expect some bugs or adjustements
  that need to be made
- Complex pane layouts won't be correctly restored, the current implementation
  to determine the pane position is extremely basic

## Contributing

Feedback, bug reports, and contributions to enhance the script are welcome.
