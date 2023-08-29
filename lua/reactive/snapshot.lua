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

  self.snapshot = { winhl = {}, hl = {} }

  -- if we're leaving a window, then we just color that window with `inactive` colors, if present
  if inactive then
    State:iterate_presets(function(preset)
      local constraints = {}

      if preset.static and not vim.tbl_isempty(preset.static) and not self:process_skip(preset.skip, constraints) then
        self:form_snapshot({
          winhl = preset.static.winhl and preset.static.winhl.inactive,
          hl = preset.static.hl,
        }, '@static.inactive', constraints)
      end
    end)

    return self.snapshot
  end

  local mode = self.to
  local mode_len = #mode

  -- store scopes of previous iterations
  local scope = {}

  local dropped_presets = {}
  local presets_len = State:count()

  local has_static = false

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
        if preset.static and not vim.tbl_isempty(preset.static) then
          has_static = true
        end

        -- we check `skip` method/table only on a first iteration
        if self:process_skip(preset.skip, scope[preset.name].constraints) then
          dropped_presets[preset.name] = true

          return
        end

        self:merge_snapshot(inc_mode, inc_mode_config, scope[preset.name].constraints)

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
          Util.eachi(shape_fields, function(val)
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

        self:merge_snapshot(inc_mode, inc_mode_config, local_constraints)
      end
    end)
  end)

  if has_static then
    State:iterate_presets(function(preset)
      if preset.static and not vim.tbl_isempty(preset.static) then
        self:form_snapshot({
          winhl = preset.static.winhl and preset.static.winhl.active,
          hl = preset.static.hl,
        }, '@static.active', scope[preset.name].constraints)
      end
    end)
  end

  self.current_opfunc = nil

  return self.snapshot
end

---@param inc_mode string
---@param inc_mode_config Reactive.TriggerConfig
---@param constraints TriggerConstraints<boolean>
function M:merge_snapshot(inc_mode, inc_mode_config, constraints)
  if Util.is_op(inc_mode) and inc_mode_config.operators then
    local op = vim.v.operator

    if op and inc_mode_config.operators[op] then
      if
        op == 'g@'
        and self.current_opfunc
        and inc_mode_config.operators[op].opfuncs
        and inc_mode_config.operators[op].opfuncs[self.current_opfunc]
      then
        self:form_snapshot(
          inc_mode_config.operators[op].opfuncs[self.current_opfunc],
          ('@mode.%s.@op.g@.%s'):format(inc_mode, self.current_opfunc),
          constraints
        )
      end

      self:form_snapshot(inc_mode_config.operators[op], ('@mode.%s.@op.%s'):format(inc_mode, op), constraints)
    end
  end

  self:form_snapshot(inc_mode_config, ('@mode.%s'):format(inc_mode), constraints)
end

local merge_handlers = {
  winhl = function(highlights, scope)
    Util.each(highlights, function(hl_group, hl_val)
      if M.snapshot.winhl[hl_group] then
        return
      end

      if type(hl_val) == 'table' then
        local rhs = Util.transform_winhl(hl_group, hl_val, scope)

        -- update preset itself to contain a binding instead of a table value
        highlights[hl_group] = rhs

        M.snapshot.winhl[hl_group] = rhs
      else
        M.snapshot.winhl[hl_group] = hl_val
      end
    end)
  end,
  hl = function(highlights)
    for hl, val in pairs(highlights) do
      if not M.snapshot.hl[hl] then
        M.snapshot.hl[hl] = val
      end
    end
  end,
}

function M:form_snapshot(highlights, scope, constraints)
  Util.each(merge_handlers, function(value)
    if not highlights[value] or constraints and constraints[value] then
      return
    end

    merge_handlers[value](highlights[value], scope)
  end)
end

---@param skip table | fun(): boolean
---@param constraints? table<string, boolean>
---@return boolean is_dropped
function M:process_skip(skip, constraints)
  if type(skip) == 'function' then
    return skip()
  end

  if not skip or type(skip) == 'table' and vim.tbl_isempty(skip) then
    return false
  end

  local escaped = true

  for _, field in ipairs(shape_fields) do
    if skip[field] and skip[field]() then
      if constraints then
        constraints[field] = true
      end
    else
      escaped = false
    end
  end

  return escaped
end

return M
