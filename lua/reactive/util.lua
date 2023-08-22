local M = {}

--- Sets highlight
function M.set_hl(name, val)
  return vim.api.nvim_set_hl(0, name, val)
end

--- Clears and deletes highlight
function M.clear_hl(hl)
  return vim.cmd('hi clear ' .. hl)
end

--- Checks if a mode is operator-pending and if it is, whether a motion is forced
---@param mode string
---@return boolean is_op_mode, boolean? forced
function M.is_op(mode)
  return mode:find 'no' ~= nil
end

--- Checks if a mode is normal
---@param mode string
---@return boolean is_normal_mode
function M.is_normal(mode)
  return not M.is_op(mode) and mode:find 'n' ~= nil
end

--- Deeply merges two tables without index/numeric keys
---@param to table<any>
---@param from table<any>
---@param skip_existing? boolean
---@return table<any> result
function M.deep_merge(to, from, skip_existing)
  -- making a shallow copy
  local result = M.shallow_copy(to)

  for key, value in pairs(from) do
    if not result[key] then
      result[key] = value
    else
      if type(result[key]) ~= 'table' then
        if not skip_existing then
          result[key] = value
        end
      else
        result[key] = M.deep_merge(result[key], value, skip_existing)
      end
    end
  end

  return result
end

--- Creates a shallow copy of a table without index/numeric keys
---@param tbl table<any>
---@return table<any> shallow_copied_table
function M.shallow_copy(tbl)
  local copied_tbl = {}

  for k, v in pairs(tbl) do
    copied_tbl[k] = v
  end

  return copied_tbl
end

-- list of all possible invalid characters for naming a hl group
-- in modes and operators
local invalid_chars_dict = {
  ['<'] = '@sl',
  ['>'] = '@sr',
  ['~'] = '@t',
  ['!'] = '@em',
  ['?'] = '@qm',
  ['='] = '@es',
  -- Neovim has case-insensitive highlight groups, meaning that 'gu' and 'gU'
  -- operators will result in having the same highlight group.
  -- That's why we should transform this char to make it unique.
  U = '@U',
  -- select mode
  ['\x13'] = '@Cs',
  -- visual mode
  ['\x16'] = '@Cv',
}

local invalid_chars_pattern = '[<>~U!?=\x13\x16]'
local hl_mode_template = 'Reactive%s@mode.%s'
local hl_op_template = hl_mode_template .. '.@op.%s'

--- Transforms highlight into a unique string
---@param hl string
---@param val table<string, any>
---@param mode string
---@param op_prefix? string
---@return string transformed_winhl
function M.transform_winhl(hl, val, mode, op_prefix)
  mode = mode:gsub(invalid_chars_pattern, invalid_chars_dict)

  -- create binding for hl group
  local rhs

  if op_prefix and M.is_op(mode) then
    rhs = hl_op_template:format(hl, mode, op_prefix:gsub(invalid_chars_pattern, invalid_chars_dict))
  else
    rhs = hl_mode_template:format(hl, mode)
  end

  M.set_hl(rhs, val)

  return rhs
end

---@generic V
---@param t table<string | table<string>, V>
---@param fn fun(key: string, value: V, shared: boolean)
function M.trigger_each(t, fn)
  for key, value in pairs(t) do
    if type(key) == 'table' then
      for _, k in ipairs(key) do
        fn(k, value, true)
      end
    else
      fn(key, value, false)
    end
  end
end

---@generic V
---@param t table<string, V>
---@param fn fun(key:string, value:V): boolean?
function M.each(t, fn)
  for k, v in pairs(t) do
    if fn(k, v) == true then
      break
    end
  end
end

---@generic V
---@param t table<V>
---@param fn fun(index:number, value:V): boolean?
function M.eachi(t, fn)
  for i, v in ipairs(t) do
    if fn(i, v) == true then
      break
    end
  end
end

--- Iterates through a mode backwards, incrementally passing a sub-mode
--- into a function argument. If a function returns true, breaks the loop.
---@param mode string
---@param fn fun(inc_mode: string, len: number): boolean?
function M.iterate_mode_reverse(mode, fn)
  for i = #mode, 1, -1 do
    -- we pass the shorter version of a mode on each iteration
    if fn(mode:sub(1, i), i) == true then
      break
    end
  end
end

return M
