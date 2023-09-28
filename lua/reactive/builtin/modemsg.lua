---@type Reactive.Preset
return {
  name = 'modemsg',
  init = function()
    vim.api.nvim_set_hl(0, 'ModeMsg', { link = 'ReactiveModeMsg' })
  end,
  skip = {
    hl = function()
      return not vim.api.nvim_get_option 'showmode'
    end,
  },
  modes = {
    i = {
      hl = {
        ReactiveModeMsg = { fg = '#5eead4' },
      },
    },
    R = {
      hl = {
        ReactiveModeMsg = { fg = '#67e8f9' },
      },
    },
    -- visual
    [{ 'v', 'V', '\x16' }] = {
      hl = {
        ReactiveModeMsg = { fg = '#d8b4fe' },
      },
    },
    -- select
    [{ 's', 'S', '\x13' }] = {
      hl = {
        ReactiveModeMsg = { fg = '#c4b5fd' },
      },
    },
  },
}
