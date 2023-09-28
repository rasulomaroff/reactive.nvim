if vim.g.loaded_reactive then
  return
end
vim.g.loaded_reactive = true

local api = vim.api
local aucmd = api.nvim_create_autocmd

local function clear_aucmds()
  -- pcall to prevent errors when double disabling a plugin
  local ok = pcall(api.nvim_del_augroup_by_name, 'reactive.nvim')

  if not ok then
    return
  end

  local Snapshot = require 'reactive.snapshot'

  for hl in pairs(Snapshot.cached_hl) do
    vim.cmd('highlight clear ' .. hl)
  end

  Snapshot.cached_hl = {}
end

local function init_aucmds()
  local group = api.nvim_create_augroup('reactive.nvim', { clear = true })

  local Highlight = require 'reactive.highlight'
  local Snapshot = require 'reactive.snapshot'

  aucmd('ModeChanged', {
    group = group,
    pattern = '*:*',
    desc = 'Reactive: watches for mode changes to update highlights and run callbacks',
    callback = function(opts)
      local from, to = unpack(vim.split(opts.match, ':'))

      Snapshot:set_modes(from, to)

      Highlight:apply(Snapshot:gen())
    end,
  })

  -- We need BufWinEnter event to successfully handle cases where you open a window
  -- then through telescope go to another one and then go back through Ctrl + o
  aucmd({ 'WinEnter', 'BufWinEnter' }, {
    group = group,
    desc = 'Reactive: applies active window highlights',
    callback = function()
      Highlight:apply(Snapshot:gen())
    end,
  })

  aucmd('WinLeave', {
    group = group,
    desc = 'Reactive: applies inactive window highlights',
    callback = function()
      Highlight:apply(Snapshot:gen(true))
    end,
  })
end

init_aucmds()

api.nvim_create_user_command('ReactiveEnable', init_aucmds, {})
api.nvim_create_user_command('ReactiveDisable', clear_aucmds, {})
