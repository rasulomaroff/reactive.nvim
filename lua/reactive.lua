---@class Reactive.Config
---@field builtin? table<string, boolean | table<string, any>>
---@field preset_configs? table<string, boolean | table<string, any>>

local M = {}

---@param config Reactive.Config
function M.setup(config)
  if not config or vim.tbl_isempty(config) then
    return
  end

  local State = require 'reactive.state'

  for name, preset_val in pairs(config.builtin or {}) do
    local ok, preset = pcall(require, 'reactive.builtin.' .. name)

    if not ok then
      vim.notify(
        'reactive.nvim: There is no builtin preset called ' .. name .. '. Possible values: cursorline, cursor, modemsg',
        vim.log.levels.ERROR
      )
    else
      if preset_val == true then
        State:add_preset(preset)
      elseif type(preset_val) == 'table' then
        State:add_preset(vim.tbl_deep_extend('force', preset, preset_val))
      end
    end
  end

  if config.preset_configs and not vim.tbl_isempty(config.preset_configs) then
    State:set_configs(config.preset_configs)
  end
end

---@param preset Reactive.Preset
function M.add_preset(preset)
  require('reactive.state'):add_preset(preset)
end

---@param opfunc string
function M.set_opfunc(opfunc)
  require('reactive.snapshot'):set_opfunc(opfunc)
end

return M
