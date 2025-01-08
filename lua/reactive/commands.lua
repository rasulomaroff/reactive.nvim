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
  enable_all = function()
    require('reactive.state'):enable_all_presets()
  end,
  toggle = function(preset)
    require('reactive.state'):toggle_preset(preset)
  end,
  disable = function(preset)
    require('reactive.state'):disable_preset(preset)
  end,
  disable_all = function()
    require('reactive.state'):disable_all_presets()
  end,
}

M.cached_presets = {}

function M:init()
  local Highlight = require 'reactive.highlight'
  local Snapshot = require 'reactive.snapshot'
  local Util = require 'reactive.util'
  local function clear_winhighlight_options()
    local windows = vim.api.nvim_list_wins()

    Util.eachi(windows, Util.delete_reactive_winhl)
  end

  local function clear_highlights()
    for hl in pairs(Snapshot.cache.applied_hl) do
      vim.cmd('highlight clear ' .. hl)
    end
  end

  local function init_plugin()
    if self.listeners_initialized then
      return
    end
    self.listeners_initialized = true

    local group = api.nvim_create_augroup('reactive.nvim', { clear = true })

    aucmd('ModeChanged', {
      group = group,
      pattern = '*:*',
      desc = 'Reactive: watches for mode changes to update highlights and run callbacks',
      callback = function()
        Snapshot:set_modes(vim.v.event.old_mode, vim.v.event.new_mode)
        local snap = Snapshot:gen { callbacks = true }

        Highlight:apply {
          hl = snap.hl,
          winhl = snap.winhl.current,
          winid = api.nvim_get_current_win(),
        }
      end,
    })

    aucmd('WinEnter', {
      group = group,
      desc = 'Reactive: applies active/inactive window highlights',
      callback = function()
        Highlight:sync()
      end,
    })

    -- We use this autocmd to fix the bug when after entering a file through a telescope/fzf/whatever
    -- and then jumping back through ctrl+o mapping we could get highlights for noncurrent windows or
    -- highlights for a different mode, for example having a highlights for insert mode while being in normal
    -- it may be a neovim issue (or feature?), because I don't see any reasons for it to happen
    aucmd('BufWinEnter', {
      group = group,
      desc = 'Reactive: applies active/inactive window highlights',
      callback = function()
        local snap = Snapshot:gen()
        Highlight:apply {
          hl = snap.hl,
          winhl = snap.winhl.current,
          winid = api.nvim_get_current_win(),
        }
      end,
    })

    aucmd('ColorScheme', {
      group = group,
      desc = 'Reactive: removes cached highlights',
      callback = function()
        clear_winhighlight_options()
        clear_highlights()
        Snapshot:clear_cache()
        Highlight:sync(true)
      end,
    })

    Highlight:sync(true)
  end

  local function stop_plugin()
    if not self.listeners_initialized then
      return
    end
    self.listeners_initialized = nil

    -- clear listeners
    vim.api.nvim_del_augroup_by_name 'reactive.nvim'

    clear_winhighlight_options()
    clear_highlights()
    Snapshot:clear_cache()
  end

  local function toggle_listeners()
    if self.listeners_initialized then
      stop_plugin()
    else
      init_plugin()
    end
  end

  init_plugin()

  user_cmd('ReactiveStart', init_plugin, {})
  user_cmd('ReactiveStop', stop_plugin, {})
  user_cmd('ReactiveToggle', toggle_listeners, {})
  user_cmd('Reactive', function(opts)
    local cmd, val = unpack(vim.split(vim.trim(opts.args), '%s+'))

    if not cmd or vim.trim(cmd) == '' then
      vim.notify('reactive.nvim: specify a command', vim.log.levels.ERROR)
      return
    end

    if not val then
      vim.notify('reactive.nvim: specify a preset name', vim.log.levels.ERROR)
      return
    end

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
