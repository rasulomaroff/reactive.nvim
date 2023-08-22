# reactive.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![Stars](https://img.shields.io/github/stars/rasulomaroff/reactive.nvim?style=for-the-badge)
![License](https://img.shields.io/github/license/rasulomaroff/reactive.nvim?style=for-the-badge)
[![Last commit](https://img.shields.io/github/last-commit/ecosse3/nvim?style=for-the-badge)](https://github.com/ecosse3/nvim/commits/master)

## Features

- **Performant**: `reactive.nvim` uses neovim events to apply highlights (`ModeChanged` for mode changes, `WinEnter` and `WinLeave` for coloring active/inactive windows), your input isn't monitored at all.
- **Window highlights**: apply highlights only for a current window. Utilizes `'winhighlight'` neovim-specific option. (read more `:h 'winhighlight'`).
- **Highlights**: apply global highlights.
- **Highly customizable**: ...
- **Specificity system**: ...
- **Presets**: define your own presets or use builtin ones
- **Modes**: apply different highlights for different modes.
- **Operators**: you can apply your highlights and window highlights on any operator like 'd', 'c', 'y' and others (all operators supported)
- **Custom operators**: you can even apply highlights on your custom operators! Always wanted to highlight a cursor line (or whatever), when using a specific external plugin's operator? Now it's possible.
- **Extendable**: other plugin creators (especially theme ones) can use `reactive.nvim` to add dynamic color switching to their plugins


  # README IN PROGRESS...
