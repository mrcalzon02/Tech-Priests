-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 22-36
local function ensure_root()
  if ensure_storage then pcall(ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.consecration_history_gui_0422 = storage.tech_priests.consecration_history_gui_0422 or {
    open = {},
    version = M.version,
    stats = {}
  }
  local root = storage.tech_priests.consecration_history_gui_0422
  root.open = root.open or {}
  root.stats = root.stats or {}
  root.version = M.version
  return root
end

