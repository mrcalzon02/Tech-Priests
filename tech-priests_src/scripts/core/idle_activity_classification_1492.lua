-- Pure activity classification for the 0582 idle governor.
-- Hoist common active-key names and bound memoized protected reasons.
local M = {}
local ACTIVE_KEYS = {
  "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333",
  "construction_task", "combat_target", "repair_target", "consecration_target",
  "active_consecration_0515", "active_repair_0516", "combat_repair_0517",
  "logistics_fetch_task", "active_logistics_fetch", "machine_fulfillment_task",
}
local protected_reasons = {}
local reason_count = 0
local MAX_REASON_MEMO = 128
local function lower(v) return string.lower(tostring(v or "")) end
local function valid(e) return e and e.valid end
function M.has_active_order(pair)
  if type(pair) ~= "table" then return false end
  local oq = pair.order_queue_0469 or pair.orders_0469 or pair.order_queue or pair.orders
  if type(oq) == "table" then
    if oq.current or oq.active or oq.current_order then return true end
    if type(oq.pending) == "table" and next(oq.pending) ~= nil then return true end
    if type(oq.queue) == "table" and next(oq.queue) ~= nil then return true end
  end
  for _, k in ipairs(ACTIVE_KEYS) do
    local v = pair[k]
    if valid(v) then return true end
    if type(v) == "table" then
      if v.current or v.target or v.entity or v.item or v.item_name or v.output_item or v.status == "active" then return true end
    elseif v then
      return true
    end
  end
  local mode = lower(pair.mode)
  if mode ~= "" and mode ~= "idle" and mode ~= "returning" and mode ~= "no-managed-priority-claimed" then
    if mode:find("combat",1,true) or mode:find("repair",1,true) or mode:find("consecr",1,true) or mode:find("gather",1,true) or mode:find("craft",1,true) or mode:find("construct",1,true) or mode:find("mine",1,true) or mode:find("acquir",1,true) then return true end
  end
  return false
end
function M.should_never_skip(reason)
  local key=type(reason)=="string" and reason or tostring(reason or "")
  local result=protected_reasons[key]
  if result ~= nil then return result end
  local rs=lower(key)
  result = rs:find("manual",1,true) ~= nil
    or rs:find("combat",1,true) ~= nil
    or rs:find("recovery",1,true) ~= nil
    or rs:find("repair",1,true) ~= nil
    or rs:find("force",1,true) ~= nil
    or rs:find("debug",1,true) ~= nil
  if reason_count >= MAX_REASON_MEMO then
    protected_reasons={}; reason_count=0
  end
  protected_reasons[key]=result
  reason_count=reason_count+1
  return result
end
return M
