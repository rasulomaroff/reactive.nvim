---@type Reactive.Preset
return {
  name = 'cursorline',
  init = function()
    vim.opt.cursorline = true
  end,
  static = {
    winhl = {
      inactive = {
        CursorLine = { bg = '#202020' },
        CursorLineNr = { fg = '#b0b0b0', bg = '#202020' },
      },
    },
  },
  modes = {
    no = {
      operators = {
        -- switch case
        [{ 'gu', 'gU', 'g~', '~' }] = {
          winhl = {
            CursorLine = { bg = '#334155' },
            CursorLineNr = { fg = '#cbd5e1', bg = '#334155' },
          },
        },
        -- change
        c = {
          winhl = {
            CursorLine = { bg = '#162044' },
            CursorLineNr = { fg = '#93c5fd', bg = '#162044' },
          },
        },
        -- delete
        d = {
          winhl = {
            CursorLine = { bg = '#350808' },
            CursorLineNr = { fg = '#fca5a5', bg = '#350808' },
          },
        },
        -- yank
        y = {
          winhl = {
            CursorLine = { bg = '#422006' },
            CursorLineNr = { fg = '#fdba74', bg = '#422006' },
          },
        },
      },
    },
    i = {
      winhl = {
        CursorLine = { bg = '#012828' },
        CursorLineNr = { fg = '#5eead4', bg = '#012828' },
      },
    },
    c = {
      winhl = {
        CursorLine = { bg = '#202020' },
        CursorLineNr = { fg = '#ffffff', bg = '#303030' },
      },
    },
    n = {
      winhl = {
        CursorLine = { bg = '#21202e' },
        CursorLineNr = { fg = '#ffffff', bg = '#21202e' },
      },
    },
    -- visual
    [{ 'v', 'V', '\x16' }] = {
      winhl = {
        CursorLineNr = { fg = '#d8b4fe' },
        Visual = { bg = '#3b0764' },
      },
    },
    -- select
    [{ 's', 'S', '\x13' }] = {
      winhl = {
        CursorLineNr = { fg = '#c4b5fd' },
        Visual = { bg = '#2e1065' },
      },
    },
    -- replace
    R = {
      winhl = {
        CursorLine = { bg = '#083344' },
        CursorLineNr = { fg = '#67e8f9', bg = '#083344' },
      },
    },
  },
}
