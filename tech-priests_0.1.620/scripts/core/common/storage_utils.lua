-- Tech Priests common storage helpers.
-- 0.1.421: shared utility module introduced during control.lua cleanup.

local M = {}

function M.now()
  if game then return game.tick or 0 end
  return 0
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

function M.ensure_root(key)
  local root = M.root()
  root[key] = root[key] or {}
  return root[key]
end

function M.ensure_table(parent, key)
  if not parent then return nil end
  parent[key] = parent[key] or {}
  return parent[key]
end

return M
