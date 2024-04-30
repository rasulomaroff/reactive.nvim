local M = {}

--- Sets highlight
function M.set_hl(name, val)
  return vim.api.nvim_set_hl(0, name, val)
end

--- Clears and deletes highlight
function M.clear_hl(hl)
  return vim.cmd('hi clear ' .. hl)
end

--- Returns winhighlight option value
---@param win number?
function M.get_winhl(win)
  return vim.api.nvim_win_get_option(win or 0, 'winhighlight')
end

--- Sets winhighlight option
---@param val string
---@param win number?
function M.set_winhl(val, win)
  return vim.api.nvim_win_set_option(win or 0, 'winhighlight', val)
end

--- Deletes window highlights applied by reactive.nvim
---@param win number
function M.delete_reactive_winhl(win)
  local winhl = M.get_winhl(win)

  if winhl == '' then
    return
  end

  local clear_winhl = {}

  M.each_winhl(winhl, function(from, to)
    -- we only leave those highlights not from reactive.nvim
    if not M.is_reactive_hl(to) then
      clear_winhl[from] = to
    end
  end)

  M.set_winhl(table.concat(clear_winhl, ','), win)
end

--- Iterates through winhighlight entries
---@param winhighlight string
---@param fn fun(from: string, to: string)
function M.each_winhl(winhighlight, fn)
  M.eachi(vim.split(winhighlight, ','), function(from_to)
    fn(unpack(vim.split(from_to, ':')))
  end)
end

--- Checks if a mode is operator-pending
---@param mode string
---@return boolean is_op_mode
function M.is_op(mode)
  return mode:find 'no' ~= nil
end

--- Checks if a highlight is applied by this plugin
---@param hl string
---@boolean
function M.is_reactive_hl(hl)
  return vim.fn.matchstr(hl, [[^Reactive.*@preset\.]]) ~= ''
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

--- Transforms highlight into a unique string
---@param hl string
---@param val table<string, any>
---@param scope string
---@return string transformed_winhl
function M.transform_winhl(hl, val, scope)
  scope = scope:gsub(invalid_chars_pattern, invalid_chars_dict)

  -- create binding for hl group
  local rhs = ('Reactive%s%s'):format(hl, scope)

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
---@param fn fun(value:V, index:number): boolean?
function M.eachi(t, fn)
  for i, v in ipairs(t) do
    if fn(v, i) == true then
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
