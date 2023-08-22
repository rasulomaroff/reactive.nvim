local Preset = require 'reactive.preset'
local Util = require 'reactive.util'

---@class TriggerConstraints<V>: { winhl?: V, hl?: V }

---@class Reactive.TriggerConfig
---@field winhl? table<string, string | table<string, any>>
---@field hl? table<string, table<string, any>>
---@field operators? table<string, Reactive.TriggerConfig>
---@field opfuncs? table<string, Reactive.TriggerConfig>
---@field exact? boolean | TriggerConstraints<boolean>
---@field frozen? boolean | TriggerConstraints<boolean>

---@class Reactive.Preset
---@field name string
---@field lazy? boolean
---@field priority? number
---@field skip? TriggerConstraints<fun(): boolean> | fun(): boolean
---@field modes table<string | table<string>, Reactive.TriggerConfig>
---@field init? fun(preset: Reactive.Preset)

local M = {
  -- parsed presets
  ---@type table<string, Reactive.Preset>
  presets = {},
  -- preset configs passed to the plugin's main setup function
  preset_configs = {},
  -- sorted presets by priority
  ---@type table<string>
  priority_presets = {},
  -- these presets are marked "false" in the plugin's main setup function
  disabled_presets = {},
}

function M:count()
  return #self.priority_presets
end

---@param name string
---@param priority? number
function M:insert_preset_priority(name, priority)
  local presets_len = #self.priority_presets

  -- if the array is empty or the priority isn't specified,
  -- push to the end
  if not priority or presets_len == 0 then
    table.insert(self.priority_presets, name)

    return
  end

  local inserted = false

  for idx, preset_name in ipairs(self.priority_presets) do
    if not self.presets[preset_name].priority or priority > self.presets[preset_name].priority then
      table.insert(self.priority_presets, idx, name)
      inserted = true

      break
    end
  end

  if not inserted then
    table.insert(self.priority_presets, name)
  end
end

---@param preset Reactive.Preset
function M:add_preset(preset)
  vim.validate { name = { preset.name, 'string' } }

  preset = Preset:parse(preset)

  if self.presets[preset.name] then
    self:update_preset(preset)
  else
    vim.validate { modes = { preset.modes, 'table' } }

    self:init_preset(preset)
  end
end

---@param preset Reactive.Preset
function M:update_preset(preset)
  local prev_priority = self.presets[preset.name].priority

  self.presets[preset.name] = vim.tbl_deep_extend('force', self.presets[preset.name], preset)

  if self.presets[preset.name].lazy then
    self:disable_preset(preset.name)
  else
    self:enable_preset(preset.name)

    if preset.priority and preset.priority ~= prev_priority then
      self:sort_presets()
    end
  end
end

---@param name string
---@param preset Reactive.Preset | boolean
function M:merge_preset_config(name, preset)
  if self.preset_configs[name] ~= nil then
    if type(preset) == 'table' then
      self.preset_configs[name] = vim.tbl_deep_extend('force', self.preset_configs[name], Preset:parse(preset))

      if preset.lazy ~= nil then
        self.preset_configs[name]._.enabled = not preset.lazy
      end
    else
      self.preset_configs[name].lazy = not preset
    end
  else
    if type(preset) == 'table' then
      self.preset_configs[name] = preset
      self.preset_configs[name].name = name
    else
      self.preset_configs[name] = {
        lazy = not preset,
        name = name,
      }
    end
  end
end

---@param configs table<string, Reactive.Preset | boolean>
function M:set_configs(configs)
  for name, _preset in pairs(configs) do
    self:merge_preset_config(name, _preset)

    local preset_config = self.preset_configs[name]

    if self.presets[name] then
      self:update_preset(preset_config)

      if preset_config.lazy ~= nil then
        if preset_config.lazy then
          self:disable_preset(name)
        else
          self:enable_preset(name)
        end
      end
    end
  end
end

---@param preset Reactive.Preset
function M:init_preset(preset)
  if self.preset_configs[preset.name] then
    preset = vim.tbl_deep_extend('force', self.preset_configs[preset.name], preset)
    -- we no longer need a config since we already applied it
    self.preset_configs[preset.name] = nil
  end

  if preset.init then
    preset.init(preset)
  end

  self.presets[preset.name] = preset

  if preset.lazy then
    return
  end

  -- WARN: this function should be called AFTER assigning a preset to `self.presets` table
  self:insert_preset_priority(preset.name, preset.priority)
end

---@param a string
---@param b string
---@return boolean
local function compare_presets_priority(a, b)
  return (M.presets[a].priority or 0) > (M.presets[b].priority or 0)
end

function M:sort_presets()
  table.sort(self.priority_presets, compare_presets_priority)
end

---@param name string
function M:enable_preset(name)
  if not self.disabled_presets[name] then
    return
  end

  self.disabled_presets[name] = nil

  self:insert_preset_priority(name, self.presets[name].priority)
end

---@param name string
function M:disable_preset(name)
  if self.disabled_presets[name] then
    return
  end

  self.disabled_presets[name] = true

  for idx, preset_name in ipairs(self.priority_presets) do
    if preset_name == name then
      table.remove(self.priority_presets, idx)

      break
    end
  end
end

---@param fn fun(preset: Reactive.Preset): boolean?
---@return boolean escaped
function M:iterate_presets(fn)
  local escaped = false

  Util.eachi(self.priority_presets, function(_, preset)
    if fn(self.presets[preset]) then
      escaped = true
    end
  end)

  return escaped
end

return M
