local M = {
  ---@type table<string, string>
  prev_winhl = {},
  ---@type table<string, table<string, any>>
  prev_highlights = {},
}

---@param opts { winhl?: table<string, string>, hl?: table<string, table<string, any>> }
function M:apply(opts)
  self:apply_winhl(opts.winhl)
  self:apply_hl(opts.hl)

  -- redraw pending screen updates
  -- without this command some highlights won't be applied immediately
  -- or till the next "redraw" caused by nvim itself
  vim.cmd [[ redraw ]]
end

---@param highlights table<string, string>
function M:apply_winhl(highlights)
  local current_window = vim.api.nvim_get_current_win()

  local winhl_map = {}

  local prev_win_winhl = vim.api.nvim_win_get_option(current_window, 'winhighlight')

  local has_reactive_highlights = false

  if prev_win_winhl ~= '' then
    local Util = require 'reactive.util'

    for _, from_to in ipairs(vim.split(prev_win_winhl, ',')) do
      local from, to = unpack(vim.split(from_to, ':'))
      -- we shouldn't apply previous reactive highlights since new ones are formed every update
      if not Util.is_reactive_hl(to) then
        winhl_map[from] = to
      else
        has_reactive_highlights = true
      end
    end
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

  vim.api.nvim_win_set_option(current_window, 'winhighlight', winhl_str)
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
