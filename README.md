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

- [Overview](#overview)
- [Status](#status)
- [Getting started](#getting-started)
  - [Installation](#installation)
  - [Usage](#usage)
- [Configuration](#configuration)
  - [Preset Spec](#preset-spec)
  - [TriggerConfig Spec](#triggerconfig-spec)
- [Advanced](#advanced)
  - [Custom operators](#custom-operators)
  - [Shared trigger configs](#shared-trigger-configs)
  - [Specificity](#specificity)
  - [Mode-bubbling](#mode-bubbling)
- [Extending Reactive](#extending-reactive)

## Overview



## Status

**`reactive`** is in its early stages and some fields, their values may change in favor of convenience in the future, but this should **not** stop you
from trying this plugin out. Breaking changes (if any) won't happen suddenly and unexpectedly, if they don't break the core behavior of a plugin. In other cases,
they will be marked `deprecated` and you'll be notified in your Neovim console.

## Getting started
### Requirements
Neovim version: `>= 0.7.0`

I would appreciate it if someone points from which version neovim supports both `'winhighlight'` option and `ModeChanged` event.

### Installation

- With `lazy.nvim`: 
```lua
{ 'rasulomaroff/reactive.nvim' }
```

- With `packer.nvim`
```lua
use { 'rasulomaroff/reactive.nvim' }
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

> [!NOTE]
> What is a `Trigger`? `Trigger` is a `mode`, `operator` or `operator function` (opfunc) that triggers highlights. More on this below.

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

### TriggerConfig Spec

Trigger config is a table, containing following field:

#### winhl
type: `table<string, table>`

Table of window-local highlights, that will be applied in a specific mode/operator/opfunc.
A key in this table is a name of a highlight group and value - its value. The same you set with `vim.api.nvim_set_hl(0, name, value)`.

Example:

```lua
winhl = {
  StatusLine = { fg = '#000000', bg = '#ffffff' }
}
```

#### hl
type: `table<string, table>`

Table of highlights, that will be applied in a specific mode/operator/opfunc. Very similar to `winhl`, but these highlights are set globally (in every window).
For example, `Cursor` hl group cannot be highlighted window-locally, so you can set it here.

Example:

```lua
hl = {
  Cursor = { fg = '#00ff00', bg = '#ff00ff' }
}
```

#### operators
type: `TriggerConfig`

This field allows you to configure operators as you configure modes. This is a table where a key is an operator ('d', 'y' or any other valid one),
and a value is a `TriggerConfig` spec. Highlights that you specify in this table will be prioritized over those from `modes`.

Example:

```lua
operators = {
  d = {
    winhl = {
      -- if the `no` mode has StatusLine highlight, it will be overwritten by this one below
      StatusLine = { fg = 'yourcolor', bg = 'yourcolor' }
    }
  }
}
```

> ![NOTE]
> This field can only be used inside operator-pending modes, like `no`, `nov`, `noV`, and `no\x16`.

#### opfuncs
type: `TriggerConfig`



#### exact
type: `boolean` or `{ winhl?: boolean, hl?: boolean }`

You don't really need to use this field if a mode you're configuring consists of one letter. It allows you not to apply highlights from modes
that are less specific than triggered one. For example, if you set this is as `true` for `niI` mode and that mode is triggered, `reactive` won't
apply highlights from `ni` and `n` modes. (It does it by default due to [mode-bubbling](#mode-bubbling)).
You can also pass a table identifying which field you want to be exact.

> ![NOTE]
> This field will be checked **only** for the exact mode triggered. For example, if a triggered mode is `Rv`, `reactive` will check the `exact` field only
> for `Rv` mode, not for `R`. If you would like to stop mode propagation, look at the `frozen` field. 

#### frozen
type: `boolean~ or `{ winhl?: boolean, hl?: boolean }`


A complete example of a preset can look like the following:

```lua

```


## Advanced

### Custom operators

### Shared trigger configs

You can apply the same config for several modes at once by specifying a key as an array. This also works for operators and operator functions (opfuncs).
Example:

```lua
{
  modes = {
    [{ 'n', 'i', 'v' }] = {
      -- shared trigger config for a normal, insert and visual mode
    },
    no = {
      operators = {
        [{ 'd', 'c' }] = {
          -- shared trigger config for delete and change operators
        },
        ['g@'] = {
          opfuncs = {
            [{ 'firstoperator', 'secondoperator' }] = {
              -- shared trigger config for your custom operators
            }
          }
        }
      }
    }
  }
}
```

### Specificity

### Mode-bubbling

You may think that its a performance issue, since there's no sense in first forming a table with highlights and then erase everything if the last mode is `exact` and
**_you will be right_**. This is why `Reactive` going backwards from `niI`, then `ni`, finally `n`. If `niI` has `exact` option, `reactive` will stop looking further.

## Extending Reactive

# README IN PROGRESS...
