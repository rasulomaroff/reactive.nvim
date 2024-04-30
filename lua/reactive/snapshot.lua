local Util = require 'reactive.util'

local shape_fields = { 'winhl', 'hl' }

local M = {
  current_opfunc = nil,
  from = nil,
  to = vim.fn.mode(true),
  cache = {
    applied_hl = {},
    transformed_winhl = {},
  },
}

---@param from string
---@param to string
function M:set_modes(from, to)
  self.from = from
  self.to = to
end

function M:clear_cache()
  self.cache.applied_hl = {}
  self.cache.transformed_winhl = {}
end

--- This function is meant to be used by a user/other plugin creators
--- it allows to set a custom operator when the 'g@' operator is used
---@param opfunc string
function M:set_opfunc(opfunc)
  self.current_opfunc = opfunc
end

---@param opts? { inactive_win?: boolean, callbacks?: boolean }
---@return { winhl: { current: table<string, string>, noncurrent: table<string, string> }, hl: table<string, table> }
function M:gen(opts)
  local State = require 'reactive.state'

  self.snapshot = {
    winhl = { current = {}, noncurrent = {} },
    hl = {},
  }

  local mode = self.to
  local mode_len = #mode

  -- store scopes of previous iterations
  local scope = {}

  local dropped_presets = {}
  local presets_len = State:count()

  local has_static = false

  Util.iterate_mode_reverse(mode, function(inc_mode, len)
    local is_original_mode = len == mode_len

    return State:iterate_presets(function(preset)
      if not preset.modes then
        return
      end

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

      if dropped_presets[preset.name] then
        return
      end

      if is_original_mode then
        if preset.static and not vim.tbl_isempty(preset.static) then
          has_static = true
        end

        -- we check `skip` method/table only on a first iteration
        if self:process_constraints(preset.skip, scope[preset.name].constraints) then
          dropped_presets[preset.name] = true

          return
        end

        if not inc_mode_config then
          return
        end

        self:merge {
          preset_name = preset.name,
          inc_mode = inc_mode,
          inc_mode_config = inc_mode_config,
          constraints = scope[preset.name].constraints,
        }

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
        if not inc_mode_config then
          return
        end
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

        self:merge {
          preset_name = preset.name,
          inc_mode = inc_mode,
          inc_mode_config = inc_mode_config,
          constraints = local_constraints,
        }
      end
    end)
  end)

  if has_static or (opts and opts.callbacks) then
    State:iterate_presets(function(preset)
      if preset.static and not vim.tbl_isempty(preset.static) then
        self:form {
          preset_name = preset.name,
          highlights = {
            winhl = preset.static.winhl and preset.static.winhl.active,
            hl = preset.static.hl,
          },
          scope = '@static.current',
          constraints = scope[preset.name] and scope[preset.name].constraints or {},
        }

        self:form {
          preset_name = preset.name,
          highlights = {
            winhl = preset.static.winhl and preset.static.winhl.inactive,
          },
          scope = '@static.noncurrent',
          constraints = scope[preset.name] and scope[preset.name].constraints or {},
          window_scope = 'noncurrent',
        }
      end

      if not opts or not opts.callbacks or not preset.modes or dropped_presets[preset.name] then
        return
      end

      if preset.modes[self.from] then
        if preset.modes[self.from].from then
          preset.modes[self.from].from { from = self.from, to = self.to }
        end

        -- if preset.modes[self.from].on then
        --   preset.modes[self.from].on { from = self.from, to = self.to }
        -- end
      end

      if preset.modes[self.to] then
        if preset.modes[self.to].to then
          preset.modes[self.to].to { from = self.from, to = self.to }
        end

        -- if preset.modes[self.to].on then
        --   preset.modes[self.to].on { from = self.from, to = self.to }
        -- end
      end
    end)
  end

  self.current_opfunc = nil

  return self.snapshot
end

---@param opts { preset_name: string, inc_mode: string, inc_mode_config: Reactive.ModeConfig, constraints: TriggerConstraints<boolean> }
function M:merge(opts)
  if Util.is_op(opts.inc_mode) then
    local op = vim.v.operator

    if opts.inc_mode_config.operators and opts.inc_mode_config.operators[op] then

      if
        op == 'g@'
        and self.current_opfunc
        and opts.inc_mode_config.operators[op].opfuncs
        and opts.inc_mode_config.operators[op].opfuncs[self.current_opfunc]
      then
        self:form {
          preset_name = opts.preset_name,
          highlights = opts.inc_mode_config.operators[op].opfuncs[self.current_opfunc],
          scope = ('@mode.%s.@op.g@.%s'):format(opts.inc_mode, self.current_opfunc),
          constraints = opts.constraints,
        }
      end


      self:form {
        preset_name = opts.preset_name,
        highlights = opts.inc_mode_config.operators[op],
        scope = ('@mode.%s.@op.%s'):format(opts.inc_mode, op),
        constraints = opts.constraints,
      }
    end

  end

  self:form {
    preset_name = opts.preset_name,
    highlights = opts.inc_mode_config,
    scope = ('@mode.%s'):format(opts.inc_mode),
    constraints = opts.constraints,
  }
end

local merge_handlers = {
  winhl = function(highlights, opts)
    Util.each(highlights, function(hl_group, hl_val)
      -- if a group is already applied, then we won't overwrite it
      -- meaning that it had a higher priority
      if M.snapshot.winhl[opts.window_scope][hl_group] then
        return
      end

      local key = opts.scope .. hl_group
      local cached_hl = M.cache.transformed_winhl[key]

      if not cached_hl then
        local rhs = Util.transform_winhl(hl_group, hl_val, opts.scope)
        -- collecting all transformed highlights so that we can clear them
        -- if the "ReactiveDisable" autocmd is fired
        M.cache.applied_hl[rhs] = true
        -- since we don't want to transform a highlight group and set a highlight value over and over again,
        -- it's better to cache it once and then extract from the cache
        -- but we won't cache it if this highlight is dynamic
        if not opts.nocache then
          M.cache.transformed_winhl[key] = rhs
        end

        M.snapshot.winhl[opts.window_scope][hl_group] = rhs
      else
        M.snapshot.winhl[opts.window_scope][hl_group] = cached_hl
      end
    end)
  end,
  hl = function(highlights)
    for hl, val in pairs(highlights) do
      if not M.snapshot.hl[hl] then
        -- collecting all highlights so that we can clear them
        -- if the "ReactiveDisable" autocmd is fired
        M.cache.applied_hl[hl] = true
        M.snapshot.hl[hl] = val
      end
    end
  end,
}

---@param opts { preset_name: string, highlights: table<string, table | fun(): table>, scope: string, constraints: TriggerConstraints, window_scope?: 'current' | 'noncurrent' }
function M:form(opts)
  local handler_options = {
    scope = string.format('@preset.%s.%s', opts.preset_name, opts.scope),
    preset_name = opts.preset_name,
    window_scope = opts.window_scope or 'current',
  }

  Util.each(merge_handlers, function(value)
    if not opts.highlights[value] or opts.constraints and opts.constraints[value] then
      return
    end

    local highlight_values = opts.highlights[value]

    -- highlights can be passed as a funtion and thus be dynamic
    -- in that case we won't cache their values in the `winhl` option
    -- because they can always be different
    if type(opts.highlights[value]) == 'function' then
      handler_options.nocache = true
      highlight_values = opts.highlights[value]()
    end

    merge_handlers[value](highlight_values, handler_options)
  end)
end

---@param skip table | fun(): boolean
---@param constraints? table<string, boolean>
---@return boolean is_dropped
function M:process_constraints(skip, constraints)
  if type(skip) == 'function' then
    return skip()
  end

  if not skip or type(skip) == 'table' and vim.tbl_isempty(skip) then
    return false
  end

  local escaped = true

  for _, field in ipairs { 'winhl', 'hl' } do
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
