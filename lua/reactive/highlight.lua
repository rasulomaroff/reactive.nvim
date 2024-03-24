local M = {
  ---@type table<string, table<string, any>>
  prev_highlights = {},
}

---@param opts { winid: number, winhl?: table<string, string>, hl?: table<string, table<string, any>>, forced?: boolean }
function M:apply(opts)
  local skip_winhl = self:apply_winhl(opts.winhl, opts.winid)
  local skip_hl = self:apply_hl(opts.hl, opts.forced)

  -- redraw pending screen updates
  -- without this command some highlights won't be applied immediately
  -- or till the next "redraw" caused by nvim itself
  -- but we won't redraw if it's not forced or there're no highlights applied or changed
  if not skip_winhl or not skip_hl or opts.forced then
    vim.cmd.redraw()
  end
end

---@param highlights table<string, string>
---@param winid number
---@return boolean skip_winhl
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
    return true
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

  return false
end

---@param highlights table<string, table<string, any>>
---@param forced? boolean
---@return boolean skip_hl
function M:apply_hl(highlights, forced)
  -- no sense in making the same work twice
  if not forced and vim.deep_equal(self.prev_highlights, highlights or {}) then
    return true
  end

  local Util = require 'reactive.util'

  if not highlights or vim.tbl_isempty(highlights) then
    for hl in pairs(self.prev_highlights) do
      Util.clear_hl(hl)
    end

    self.prev_highlights = {}

    return false
  end

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
  return false
end

function M:sync()
  local Util = require 'reactive.util'
  local Snapshot = require 'reactive.snapshot'
  local windows = vim.api.nvim_list_wins()
  local current_win = vim.api.nvim_get_current_win()

  Util.eachi(windows, function(win)
    if win == current_win then
      return
    end

    local snap = Snapshot:gen { inactive_win = true }
    self:apply_winhl(snap.winhl, win)
  end)

  local current_win_snap = Snapshot:gen()
  -- we'll only apply global highlights once as it makes no sense to do it
  -- several times
  self:apply {
    hl = current_win_snap.hl,
    winhl = current_win_snap.winhl,
    winid = current_win,
    -- whenever we 'sync' colors, we should forcely apply new highlights even though there
    -- could be the same highlight groups that had been applied before
    forced = true,
  }
end

return M
