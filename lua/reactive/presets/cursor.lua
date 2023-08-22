---@type Reactive.Preset
return {
  name = 'cursor',
  init = function()
    vim.opt.guicursor:append 'a:ReactiveCursor'
  end,
  modes = {
    i = {
      hl = {
        ReactiveCursor = { bg = '#5eead4' },
      },
    },
    n = {
      hl = {
        ReactiveCursor = { bg = '#ffffff' },
      },
    },
    no = {
      operators = {
        d = {
          hl = {
            ReactiveCursor = { bg = '#fca5a5' },
          },
        },
        y = {
          hl = {
            ReactiveCursor = { bg = '#fdba74' },
          },
        },
        c = {
          hl = {
            ReactiveCursor = { bg = '#93c5fd' },
          },
        },
      },
    },
    [{ 'v', 'V', '\x16' }] = {
      hl = {
        ReactiveCursor = { bg = '#d8b4fe' },
      },
    },
    c = {
      hl = {
        ReactiveCursor = { bg = '#cbd5e1' },
      },
    },
    [{ 's', 'S', '\x13' }] = {
      hl = {
        ReactiveCursor = { bg = '#c4b5fd' },
      },
    },
    R = {
      hl = {
        ReactiveCursor = { bg = '#67e8f9' },
      },
    },
  },
}
