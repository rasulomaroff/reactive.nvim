if vim.g.loaded_reactive then
  return
end
vim.g.loaded_reactive = true

require('reactive.commands'):init()
