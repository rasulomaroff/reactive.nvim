local Util = require 'reactive.util'

local M = {}

--- This method parse a preset and converts its triggers' table keys like [{ 'v', 'V' }]
--- to be the same as if they were specified separately. Moreover, since those table keys are used
--- as shared configurations for several modes, if there's a single mode together witn those shared
--- modes configurations, highlights from single mode specification will take priority.
---@param preset Reactive.Preset
---@return Reactive.Preset
function M:parse(preset)
  if not preset.modes or vim.tbl_isempty(preset.modes) then
    return vim.deepcopy(preset)
  end

  local preset_modes = preset.modes
  preset.modes = nil

  local parsed_preset = vim.deepcopy(preset)
  local modes = {}

  Util.trigger_each(preset_modes, function(mode, config, shared_mode_config)
    self:set_trigger(modes, mode, config, shared_mode_config)

    if not Util.is_op(mode) or not config.operators or vim.tbl_isempty(config.operators) then
      return
    end

    modes[mode].operators = {}

    Util.trigger_each(config.operators, function(operator, op_config, shared_op_config)
      self:set_trigger(modes[mode].operators, operator, op_config, shared_op_config)

      if operator ~= 'g@' or not config.opfuncs or vim.tbl_isempty(op_config.opfuncs) then
        return
      end

      modes[mode].operators['g@'].opfuncs = {}

      Util.trigger_each(config.opfuncs, function(opfunc, opfunc_config, shared_opfunc_config)
        self:set_trigger(modes[mode].operators['g@'].opfuncs, opfunc, opfunc_config, shared_opfunc_config)
      end)
    end)
  end)

  parsed_preset.modes = modes

  return parsed_preset
end

---@param path table
---@param key string
---@param config table
---@param shared boolean
function M:set_trigger(path, key, config, shared)
  -- We make a deep copy of a table since it can be used in different modes.
  -- Having the same table may result in unwanted side-effects, where one mode's changes
  -- are applied to another one.
  path[key] = path[key] and Util.deep_merge(path[key], config, shared) or vim.deepcopy(config)
end

return M
