if vim.g.loaded_reactive then
  return
end
vim.g.loaded_reactive = true

local api = vim.api

local aucmd = api.nvim_create_autocmd
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

aucmd('WinEnter', {
  group = group,
  desc = 'Reactive: applies highlights when entering a window',
  callback = function()
    Highlight:apply(Snapshot:gen())
  end,
})

aucmd('WinLeave', {
  group = group,
  desc = 'Reactive: removes highlights when leaving a window',
  callback = function()
    Highlight:apply(Snapshot:gen(true))
  end,
})
