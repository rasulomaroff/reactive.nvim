if vim.g.loaded_reactive then
  return
end
vim.g.loaded_reactive = true

local api = vim.api

local aucmd = api.nvim_create_autocmd
local group = api.nvim_create_augroup('reactive.nvim', { clear = true })

local Highlight = require 'reactive.highlight'
local Snapshot = require 'reactive.snapshot'

local last_event

aucmd('ModeChanged', {
  group = group,
  pattern = '*:*',
  desc = 'Reactive: watches for mode changes to update highlights and run callbacks',
  callback = function(opts)
    last_event = opts.event

    local from, to = unpack(vim.split(opts.match, ':'))

    Snapshot:set_modes(from, to)

    Highlight:apply(Snapshot:gen())
  end,
})

-- We need BufWinEnter event to successfully handle cases where you open a window
-- then through telescope go to another one and then go back through Ctrl + o
aucmd({ 'WinEnter', 'BufWinEnter' }, {
  group = group,
  desc = 'Reactive: applies highlights when entering a window',
  callback = function(opts)
    -- BufWinEnter event is often triggered right after `WinEnter` event,
    -- in this case we don't need to do the same work twice
    if last_event ~= 'WinEnter' or opts.event ~= 'BufWinEnter' then
      Highlight:apply(Snapshot:gen())
    end

    last_event = opts.event
  end,
})

aucmd('WinLeave', {
  group = group,
  desc = 'Reactive: removes highlights when leaving a window',
  callback = function(opts)
    last_event = opts.event
    Highlight:apply(Snapshot:gen(true))
  end,
})
