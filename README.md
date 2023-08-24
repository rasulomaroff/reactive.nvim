# reactive.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![Stars](https://img.shields.io/github/stars/rasulomaroff/reactive.nvim?style=for-the-badge)
![License](https://img.shields.io/github/license/rasulomaroff/reactive.nvim?style=for-the-badge)
[![Last commit](https://img.shields.io/github/last-commit/ecosse3/nvim?style=for-the-badge)](https://github.com/ecosse3/nvim/commits/master)

## Features

- **Performant**: `reactive.nvim` uses neovim events to apply highlights (`ModeChanged` for mode changes, `WinEnter` and `WinLeave` for coloring active/inactive windows), your input isn't monitored at all.
- **Window highlights**: apply highlights only for a current window. Utilizes `'winhighlight'` neovim-specific option. (read more `:h 'winhighlight'`).
- **Highlights**: apply/change global highlights on mode changes.
- **Highly customizable**: you can customize literally any mode, even very specific one like `niI` (triggered when you press Ctrl + o in insert mode)
- **Specificity and priority systems**: if you are coming from FrontEnd, you probably already understand what these term mean. In `Reactive` every mode has its specificity depending on its length. More of this below.
- **Presets**: define your own presets or use builtin ones.
- **Modes**: apply different highlights for different modes.
- **Operators**: you can apply your highlights and window highlights on any operator like 'd', 'c', 'y' and others (all operators supported).
- **Custom operators**: you can even apply highlights on your custom operators! Always wanted to highlight a cursor line (or whatever), when using a specific external plugin's operator? Now it's possible.
- **Extendable**: other plugin creators (especially theme ones) can use `reactive.nvim` to add dynamic highlights to their plugins.

## Table of contents

- [Status](#status)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Advanced](#advanced)
- [Extending Reactive](#extending-reactive)

## Status
## Getting started
### Requirements
Neovim version: `>= 0.7.0`

I would be glad if someone points from which version neovim supports both `'winhighlight'` option and `ModeChanged` event.

### Installation

- With `lazy.nvim`: 
```lua
{
  'rasulomaroff/reactive.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
}
```

- With `packer.nvim`
```lua
use {
  'rasulomaroff/reactive.nvim',
  event = { 'BufReadPost', 'BufNewFile' }
}
```

### Usage

To quickly understand what you can do with this plugin, just use built-in presets, but I encourage you to build your preset and not rely on built-in ones, which can be changed in the future:

```lua
require('reactive').setup {
  builtin = {
    cursorline = true,
    cursor = true,
    modemsg = true
  }
}
```

## Configuration

### Preset Spec

Only 2 fields are required: `name` and `modes`.

| Property  | Type                                                                   | Description                                                                     |
|-----------|------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| name      | `string`                                                               | This is your preset's name. It should be unique across other presets. |
| lazy      | `boolean?`                                                             | This property is meant to be used by other plugin developers. By making your preset lazy you can delay its usage till a user decides to activate it. |
| priority  | `number?`                                                              | You can set a priority of any preset, if you faced conflicting preset highlights, for example. It's not recommended to set this field, if you are a plugin developer. |
| skip      | `fun()?: boolean` or `{ winhl?: fun(): boolean, hl?: fun(): boolean }` | This function will be called on every mode change, so that you can define when your preset shouldn't be applied. It should return true, if you want to skip applying highlights. You can also pass a table with functions, if you want to disable only winhighlights or highlights. |
| init      | `fun()?`                                                               | This function will be called once when a preset inits.                                                                       |
| modes     | `table<string, TriggerConfig>`                                         | This is a table where a key is a mode (check `:h mode()` for understanding all the modes Neovim has), and a value is a TriggerConfig specification.  |
| operators | `table<string, TriggerConfig>`||
| opfuncs   | `table<string, TriggerConfig>`||

**Example:**

```lua
local my_preset = {
  name = 'my-preset',
  skip = function()
    return vim.api.nvim_buf_get_option(0, 'buftype') == ''
  end,
  modes = {
    n = {
      -- normal mode configuration
    },
    i = {
      -- insert mode configuration
    }
  }
}
```

> [!NOTE]
> What is a `trigger`? `Trigger` is a `mode`, `operator` or `operator function` (opfunc) that triggers highlights. More on this below.

### TriggerConfig Spec

## Advanced

### Specificity

## Extending Reactive

# README IN PROGRESS...
