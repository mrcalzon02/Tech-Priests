-- Lazy invalidation for per-priest idle caches: preserve record tables.
-- A world event updates one scalar; the next read invalidates only that reader.
local M = {}
function M.world_changed(root)
  root.world_change_epoch_1491=(tonumber(root.world_change_epoch_1491) or 0)+1
  return root.world_change_epoch_1491
end
function M.cache_record(root, key)
  local epoch=tonumber(root.world_change_epoch_1491) or 0
  local rec=root.pair[key]
  if not rec then
    rec={world_change_epoch_1491=epoch}
    root.pair[key]=rec
    return rec,false
  end
  if rec.world_change_epoch_1491 ~= epoch then
    rec.next_dispatch_after=0
    rec.next_legacy_after=0
    rec.world_change_epoch_1491=epoch
    return rec,true
  end
  return rec,false
end
return M
