-- Fast, save-compatible reservation-root normalization.
-- No derived data is written to Factorio storage. Lua module state is
-- naturally discarded when a save is reloaded or a new game is entered.
local M = {}
local memo = {}

function M.get(store, namespace, version, categories)
  local tp = store.tech_priests
  if type(tp) ~= "table" then
    tp = {}
    store.tech_priests = tp
  end
  local root = tp[namespace]
  local cache = memo[namespace]
  if type(root) == "table" and cache and cache.root == root
      and cache.reservations == root.reservations
      and cache.stats == root.stats
      and root.enabled ~= nil and root.position_scope_integrated == true
      and root.version == version then
    return root
  end

  if type(root) ~= "table" then
    root = {
      version = version, enabled = true, position_scope_integrated = true,
      reservations = {}, stats = {}, cleanup_cursor_0620 = 1,
    }
    tp[namespace] = root
  end
  root.version = version
  if root.enabled == nil then root.enabled = true end
  root.position_scope_integrated = true
  if type(root.reservations) ~= "table" then root.reservations = {} end
  if type(root.stats) ~= "table" then root.stats = {} end
  for _, category in ipairs(categories) do
    if type(root.reservations[category]) ~= "table" then
      root.reservations[category] = {}
    end
  end
  memo[namespace] = {
    root = root, reservations = root.reservations, stats = root.stats,
  }
  return root
end

return M
