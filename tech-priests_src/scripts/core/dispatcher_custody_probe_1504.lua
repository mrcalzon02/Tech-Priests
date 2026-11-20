-- Allocation-bounded diagnostic probe for 0528 machine-return custody.
-- Only the current scalar report is persisted; comparison snapshots are weak,
-- module-local, and reconstructed after a load. No behavior/custody ownership.
local M = {}
local snapshots = setmetatable({}, { __mode = "k" })

local function safe(value)
  if value == nil then return "nil" end
  local kind = type(value)
  if kind == "string" then return value end
  if kind == "boolean" or kind == "number" then return tostring(value) end
  local ok, output = pcall(tostring, value)
  return ok and output or "?"
end

local function flag(mask, bit)
  return math.floor(mask / bit) % 2 == 1 and "true" or "false"
end

local function signature_for(mask, combat, machine, order, movement)
  return table.concat({
    "0528-custody=" .. flag(mask, 1),
    "pair-0528-custody=" .. flag(mask, 2),
    "direct-custody=" .. flag(mask, 4),
    "direct-active=" .. flag(mask, 8),
    "defense-task=" .. flag(mask, 16),
    "combat-target=" .. combat,
    "machine-valid=" .. machine,
    "order=" .. order,
    "movement-owner=" .. movement,
  }, ",")
end

-- direct_active, combat_valid and machine_valid are values from the
-- dispatcher's existing checks, not newly inferred ownership decisions.
-- Returns emit, signature_if_emitting, and persisted scalar probe record.
function M.update(pair, pending, tick, direct_active, combat_valid, machine_valid)
  if not (pair and type(pending) == "table") then return false, nil, nil end
  tick = tonumber(tick) or 0
  local mask = (pending.custody ~= nil and 1 or 0)
    + (pair.machine_logistics_custody_0528 ~= nil and 2 or 0)
    + (pair.direct_acquisition_custody_0513 ~= nil and 4 or 0)
    + (direct_active and 8 or 0)
    + (pair.defense_task_0259 ~= nil and 16 or 0)
  local combat = safe(combat_valid)
  local machine = safe(machine_valid)
  local order_record = pair.order_queue_0469 and pair.order_queue_0469.current
    or pair.active_order_0469
  local order = safe(order_record and order_record.kind)
  local movement = safe(pair.movement_request_0418
    and pair.movement_request_0418.owner)
  local previous = pair.machine_return_entry_probe_0510
  local snapshot = snapshots[pair]
  local changed = not snapshot or snapshot.record ~= previous
    or snapshot.mask ~= mask or snapshot.combat ~= combat
    or snapshot.machine ~= machine or snapshot.order ~= order
    or snapshot.movement ~= movement
  local expired = tick - (tonumber(previous and previous.last_log_tick) or 0) >= 600
  local signature, emit
  if changed or expired or not previous then
    signature = signature_for(mask, combat, machine, order, movement)
    emit = not previous or previous.signature ~= signature or expired
    if not snapshot then
      snapshot = {}
      snapshots[pair] = snapshot
    end
    snapshot.record = previous
    snapshot.mask, snapshot.combat, snapshot.machine = mask, combat, machine
    snapshot.order, snapshot.movement = order, movement
  end

  local record = previous
  if not record then
    record = {}
    pair.machine_return_entry_probe_0510 = record
    -- Keep weak-map record identity coherent from the first observation.
    snapshot.record = record
  end
  record.tick = tick
  record.last_service_tick = pending.active_updated_tick
  if emit then
    record.signature = signature
    record.last_log_tick = tick
  end
  return emit == true, emit and signature or nil, record
end

return M
