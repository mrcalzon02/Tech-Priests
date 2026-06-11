-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1975-1992
local function action_readable_0494(action, order, task_name, task)
  local kind = tostring(action and action.kind or task_name or "idle")
  local item = action and action.item or display_order_item_0494(order, task)
  local labels = {
    acquisition = "Acquiring",
    crafting = "Crafting",
    combat = "Defending",
    repair = "Repair rite",
    consecration = "Consecration rite",
    conversation = "Conversing",
    idle = "Awaiting writ",
    invalid = "Pair memory fault"
  }
  local base = labels[kind] or kind
  if item and tostring(item) ~= "" then return base .. " " .. tostring(item) end
  return base
end

