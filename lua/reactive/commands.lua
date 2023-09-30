local api = vim.api
local aucmd = api.nvim_create_autocmd
local user_cmd = api.nvim_create_user_command

local M = {
  listeners_initialized = nil,
}

---@param line string
---@return string[]
local function parse_cmd(line)
  local cmd_parts = vim.split(vim.trim(line), '%s+')

  if cmd_parts[1]:find 'Reactive' then
    table.remove(cmd_parts, 1)
  end

  if line:sub(-1) == ' ' then
    table.insert(cmd_parts, '')
  end

  return cmd_parts
end

M.commands = {
  -- todo:
  -- health = function() end,
  enable = function(preset)
    require('reactive.state'):enable_preset(preset)
  end,
  toggle = function(preset)
    require('reactive.state'):toggle_preset(preset)
  end,
  disable = function(preset)
    require('reactive.state'):disable_preset(preset)
  end,
}

M.cached_presets = {}

function M:init()
  local function init_listeners()
    if self.listeners_initialized then
      return
    end
    self.listeners_initialized = true

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

        Highlight:apply(Snapshot:gen { callbacks = true })
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
        Highlight:apply(Snapshot:gen { inactive_win = true })
      end,
    })
  end

  local function clear_listeners()
    if not self.listeners_initialized then
      return
    end
    self.listeners_initialized = nil

    vim.api.nvim_del_augroup_by_name 'reactive.nvim'

    local Snapshot = require 'reactive.snapshot'

    for hl in pairs(Snapshot.cache.applied_hl) do
      vim.cmd('highlight clear ' .. hl)
    end

    Snapshot:clear_cache()
  end

  local function toggle_listeners()
    if self.listeners_initialized then
      clear_listeners()
    else
      init_listeners()
    end
  end

  init_listeners()

  user_cmd('ReactiveStart', init_listeners, {})
  user_cmd('ReactiveStop', clear_listeners, {})
  user_cmd('ReactiveToggle', toggle_listeners, {})
  user_cmd('Reactive', function(opts)
    local cmd, val = unpack(vim.split(vim.trim(opts.args), '%s+'))

    if not self.commands[cmd] then
      vim.notify('reactive.nvim: There\'s no such a command: ' .. cmd, vim.log.levels.ERROR)
    elseif not require('reactive.state').presets[val] then
      vim.notify('reactive.nvim: There\'s no such a preset: ' .. val, vim.log.levels.ERROR)
    else
      self.commands[cmd](val)
    end
  end, {
    complete = function(_, line)
      local cmd = parse_cmd(line)

      if #cmd == 1 then
        -- we only do this once
        if cmd[1] == '' then
          local State = require 'reactive.state'
          local Util = require 'reactive.util'

          self.cached_presets.toggle = {}
          self.cached_presets.enable = {}
          self.cached_presets.disable = {}

          Util.each(State.presets, function(name, preset)
            table.insert(self.cached_presets.toggle, name)

            if preset.lazy == true then
              table.insert(self.cached_presets.enable, name)
            else
              table.insert(self.cached_presets.disable, name)
            end
          end)
        end

        return vim.tbl_keys(M.commands)
      end

      if #cmd > 1 and M.commands[cmd[1]] then
        return self.cached_presets[cmd[1]]
      end
    end,
    nargs = '?',
  })
end

return M
