local Util = require 'reactive.util'

local shape_fields = { 'winhl', 'hl' }

local M = {
  current_opfunc = nil,
  from = nil,
  to = vim.fn.mode(true),
}

---@param from string
---@param to string
function M:set_modes(from, to)
  self.from = from
  self.to = to
end

--- This function is meant to be used by a user/other plugin creators
--- it allows to set a custom operator when the 'g@' operator is used
---@param opfunc string
function M:set_opfunc(opfunc)
  self.current_opfunc = opfunc
end

---@param inactive? boolean
---@return table<any>
function M:gen(inactive)
  local State = require 'reactive.state'

  self.snapshot = {}

  local mode = inactive and 'n' or self.to
  local mode_len = #mode

  -- store scopes of previous iterations
  local scope = {}

  local dropped_presets = {}
  local presets_len = State:count()

  Util.iterate_mode_reverse(mode, function(inc_mode, len)
    return State:iterate_presets(function(preset)
      if presets_len == vim.tbl_count(dropped_presets) then
        -- all presets are dropped, break the loop
        return true
      end

      -- initializing a scope
      if not scope[preset.name] then
        scope[preset.name] = {}
      end

      -- initializing constraints
      if not scope[preset.name].constraints then
        scope[preset.name].constraints = {}
      end

      local inc_mode_config = preset.modes[inc_mode]

      if dropped_presets[preset.name] or not inc_mode_config then
        return
      end

      if len == mode_len then
        -- we check `skip` method/table only on a first iteration
        if type(preset.skip) == 'table' then
          ---@diagnostic disable-next-line: param-type-mismatch
          if not vim.tbl_isempty(preset.skip) then
            local escaped = true

            for _, field in ipairs(shape_fields) do
              if preset.skip[field] and preset.skip[field]() then
                scope[preset.name].constraints[field] = true
              else
                escaped = false
              end
            end

            if escaped then
              dropped_presets[preset.name] = true

              return
            end
          elseif type(preset.skip) == 'function' and preset.skip() then
            dropped_presets[preset.name] = true

            return
          end
        end

        self:merge_shape(inc_mode, inc_mode_config, scope[preset.name].constraints)

        if len > 1 and inc_mode_config.exact then
          if type(inc_mode_config.exact) == 'boolean' then
            dropped_presets[preset.name] = true
          elseif type(inc_mode_config.exact) == 'table' then
            local stop = true

            for _, val in ipairs(shape_fields) do
              if not inc_mode_config.exact[val] then
                stop = false
                scope[preset.name].constraints = inc_mode_config.exact
                break
              end
            end

            if stop then
              dropped_presets[preset.name] = true
            end
          end
        end
      else
        -- we shouldn't mutate original constraints
        local local_constraints = vim.deepcopy(scope[preset.name].constraints)

        if type(inc_mode_config.frozen) == 'table' then
          local stop = true

          -- constraints are coming from the "exact", "frozen" and "skip" flags or absent initially
          -- if frozen + exact + skip constraint flags results in disabling all the possible
          -- shape fields, then we just skip this iteration
          Util.eachi(shape_fields, function(_, val)
            -- if a current constraint is true, then we shouldn't process this constraint at all
            if local_constraints[val] then
              return
            end
            -- if one of current + merged constraints is false then we shouldn't
            -- skip this iteration
            if not inc_mode_config.frozen[val] then
              stop = false
            else
              local_constraints[val] = true
            end
          end)

          if stop then
            -- just skip this iteration
            return
          end
        elseif inc_mode_config.frozen == true then
          -- if the 'frozen' flag passed as 'true' value, it shouldn't hoist at all
          return
        end

        self:merge_shape(inc_mode, inc_mode_config, local_constraints)
      end
    end)
  end)

  self.current_opfunc = nil

  return self.snapshot
end

local merge_handlers = {
  winhl = function(winhl_shape, preset_winhl, mode, op, current_opfunc)
    for hl_group, hl_val in pairs(preset_winhl or {}) do
      if not winhl_shape[hl_group] then
        if type(hl_val) == 'table' then
          local rhs

          if op == 'g@' and current_opfunc then
            rhs = Util.transform_winhl(hl_group, hl_val, mode, op .. '.' .. current_opfunc)
          else
            rhs = Util.transform_winhl(hl_group, hl_val, mode, op)
          end

          -- update preset itself
          if preset_winhl then
            preset_winhl[hl_group] = rhs
          end

          winhl_shape[hl_group] = rhs
        else
          winhl_shape[hl_group] = hl_val
        end
      end
    end
  end,
  hl = function(hl_shape, preset_hl)
    for hl, val in pairs(preset_hl) do
      if not hl_shape[hl] then
        hl_shape[hl] = val
      end
    end
  end,
}

---@param inc_mode string
---@param inc_mode_config Reactive.TriggerConfig
---@param constraints TriggerConstraints<boolean>
function M:merge_shape(inc_mode, inc_mode_config, constraints)
  for field, handler in pairs(merge_handlers) do
    if not constraints[field] then
      if not self.snapshot[field] then
        self.snapshot[field] = {}
      end

      if Util.is_op(inc_mode) and inc_mode_config.operators then
        local op = vim.v.operator

        if op and inc_mode_config.operators[op] then
          if
            op == 'g@'
            and self.current_opfunc
            and inc_mode_config.operators[op].opfuncs
            and inc_mode_config.operators[op].opfuncs[self.current_opfunc]
          then
            handler(
              self.snapshot[field],
              inc_mode_config.operators[op].opfuncs[self.current_opfunc][field] or {},
              inc_mode,
              op,
              self.current_opfunc
            )
          end

          handler(self.snapshot[field], inc_mode_config.operators[op][field] or {}, inc_mode, op)
        end
      end

      handler(self.snapshot[field], inc_mode_config[field] or {}, inc_mode)
    end
  end
end

return M
