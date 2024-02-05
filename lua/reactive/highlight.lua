local M = {
  ---@type table<string, table<string, any>>
  prev_highlights = {},
}

---@param opts { winid: number, winhl?: table<string, string>, hl?: table<string, table<string, any>> }
function M:apply(opts)
  self:apply_winhl(opts.winhl, opts.winid)
  self:apply_hl(opts.hl)

  -- redraw pending screen updates
  -- without this command some highlights won't be applied immediately
  -- or till the next "redraw" caused by nvim itself
  vim.cmd [[ redraw ]]
end

---@param highlights table<string, string>
---@param winid number
function M:apply_winhl(highlights, winid)
  local Util = require 'reactive.util'
  local winhl_map = {}
  local prev_win_winhl = Util.get_winhl(winid)
  local has_reactive_highlights = false

  if prev_win_winhl ~= '' then
    Util.each_winhl(prev_win_winhl, function(from, to)
      -- we shouldn't apply previous reactive highlights since new ones are formed every update
      if not Util.is_reactive_hl(to) then
        winhl_map[from] = to
      else
        has_reactive_highlights = true
      end
    end)
  end

  -- if there were no highlights applied before and passed highlights
  -- are empty, then just skip
  if not has_reactive_highlights and vim.tbl_isempty(highlights) then
    return
  end

  for from, to in pairs(highlights) do
    winhl_map[from] = to
  end

  local winhl_str = ''

  for from, to in pairs(winhl_map) do
    winhl_str = winhl_str .. from .. ':' .. to .. ','
  end

  --- removing trailing comma
  ---@type string
  winhl_str = winhl_str:sub(1, winhl_str:len() - 1)

  Util.set_winhl(winhl_str, winid)
end

---@param highlights table<string, table<string, any>>
function M:apply_hl(highlights)
  -- no sense in making the same work twice
  if vim.deep_equal(self.prev_highlights, highlights or {}) then
    return
  end

  local Util = require 'reactive.util'

  if not highlights or vim.tbl_isempty(highlights) then
    for hl in pairs(self.prev_highlights) do
      Util.clear_hl(hl)
    end

    self.prev_highlights = {}
  else
    local new_highlights = {}

    for hl, val in pairs(highlights) do
      Util.set_hl(hl, val)

      new_highlights[hl] = true
      self.prev_highlights[hl] = nil
    end

    -- clear old highlights
    for hl, _ in pairs(self.prev_highlights) do
      Util.clear_hl(hl)
    end

    self.prev_highlights = new_highlights
  end
end

return M
