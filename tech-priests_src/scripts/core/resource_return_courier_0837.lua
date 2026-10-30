-- Method I: mine a natural ore entity into an engine-owned courier inventory,
-- then physically carry its exact product to the immediate upstream station.
-- Every later hop must separately pick up and deliver the same real item.
-- Machine output may enter the same ranked relay only after the canonical
-- 0528 receiver-to-station physical receipt and local priest pickup.
local Chain=require("scripts.core.resource_station_chain_0820")
-- Factorio only permits require() while control.lua is being parsed. Cache the
-- canonical controller here; movement events must never load a module.
local MovementController=require("scripts.core.movement_controller")
-- The direct-acquisition executor alone knows whether its apparent travel
-- mode still has a live physical extraction task.
local DirectAcquisition=require("scripts.core.direct_acquisition_executor_0513")
local OrderQueue=require("scripts.core.order_queue_0469")
local M={version="0.1.674-dev.0845",reach_sq=25,interval=60}
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function dist2(a,b)
  if not (a and b) then return math.huge end
  local x,y=a.x-b.x,a.y-b.y
  return x*x+y*y
end
local function pair(id)
  local tp=storage and storage.tech_priests
  local pairs=tp and tp.pairs_by_station or {}
  return pairs[id] or pairs[tostring(id)]
end
local function count(inv,item)
  if not (valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and tonumber(n) or nil
end
-- 0982: persist primitive-only evidence for each real upstream receipt.
-- Old in-flight saves remain readable; new couriers cannot skip a hop.
function M.validate_receipts_0982(state,route)
  local ledger=state and state.receipts_0982
  if ledger==nil then return true,"legacy-in-flight-courier" end
  if type(ledger)~="table" or type(route)~="table" then
    return false,"ledger-or-route-invalid"
  end
  local n=#ledger
  if n~=(state.hops_completed or 0) or n>=#route then
    return false,"ledger-count-mismatch"
  end
  local previous_tick=-1
  for i,receipt in ipairs(ledger) do
    if type(receipt)~="table" or receipt.hop~=i
        or receipt.source_station_unit~=route[i]
        or receipt.destination_station_unit~=route[i+1]
        or receipt.source_station_unit==receipt.destination_station_unit
        or type(receipt.carrier_priest_unit)~="number"
        or receipt.item~=state.item or receipt.quantity~=1
        or type(receipt.destination_before)~="number"
        or receipt.destination_after~=receipt.destination_before+1
        or type(receipt.tick)~="number" or receipt.tick<=previous_tick then
      return false,"invalid-receipt:"..i
    end
    previous_tick=receipt.tick
  end
  for key in pairs(ledger) do
    if type(key)~="number" or key<1 or key>n
        or key~=math.floor(key) then
      return false,"non-sequential-receipt-key"
    end
  end
  return true,"physical-receipt-ledger-verified"
end
local function blocked(state,reason)
  state.phase="custody-blocked"
  state.last_reason=reason
  state.updated_tick=now()
  return false,reason
end
-- A raw go_to_location was repeatedly overridden by leash enforcement in
-- Factorio 2.0.77. Submit real navigation through the canonical 0418 owner.
local function move(worker,pos,reason)
  if not(MovementController and type(MovementController.request)=="function") then
    return false,"physical-movement-controller-unavailable"
  end
  local ok,accepted,why=pcall(MovementController.request,worker,pos,reason,{
    owner="resource-return-courier-0953",priority=72,ttl=600,radius=2,
    bounds_exempt=true,skip_corridor_planner=true,
    distraction=defines and defines.distraction and defines.distraction.none,
  })
  if not ok then return false,"physical-movement-controller-error" end
  return accepted==true,accepted==true and "physical-movement-requested"
    or (why or "physical-movement-request-refused")
end
local function ore_product_is_exact(ore,item)
  if not (valid(ore) and ore.type=="resource"
      and prototypes and prototypes.item and prototypes.item[item]) then
    return false
  end
  local ok,properties=pcall(function()
    return ore.prototype and ore.prototype.mineable_properties
  end)
  if not (ok and properties and properties.products) then return false end
  local found=false
  for _,product in pairs(properties.products) do
    if product.type=="fluid" or product.name~=item then return false end
    found=true
  end
  return found
end
local function natural_ore(source,mission)
  local scans=rawget(_G,"TechPriestsScanRouting0610")
  if not (scans and type(scans.find_entities)=="function") then
    return nil,"canonical-resource-scan-unavailable"
  end
  local pos=mission.target
  local filter={
    name=mission.resource_name,type="resource",
    area={{pos.x-4,pos.y-4},{pos.x+4,pos.y+4}},limit=8,
  }
  local radius=type(Chain.operating_radius)=="function"
    and Chain.operating_radius(source)
    or (tonumber(source.radius or source.base_radius) or 20)
  local last_reason="natural-ore-not-found"
  local function eligible(entities)
    for _,ore in ipairs(entities or {}) do
      if valid(ore) and ore.name==mission.resource_name
          and ore.surface==source.station.surface
          and tonumber(ore.amount) and ore.amount>0 then
        if dist2(source.station.position,ore.position)>radius*radius then
          last_reason="natural-ore-outside-station-radius"
        elseif not ore_product_is_exact(ore,mission.need) then
          last_reason="natural-ore-product-not-exact"
        else
          return ore
        end
      end
    end
    return nil
  end
  -- Request a live engine read through the existing 0610 scan authority.
  -- The distant patch was chunk-generated after 0579 indexed the area; an
  -- empty cached result is not proof a natural ore entity disappeared.
  local ok,found=pcall(scans.find_entities,source.station.surface,filter,
    {category="resource",limit=8,require_fresh=true})
  if not ok then return nil,"resource-scan-failed" end
  local ore=eligible(found)
  if ore then return ore end
  return nil,last_reason
end
local function station_inventory(station)
  if not valid(station) then return nil end
  -- 1000: 0686 deposits ranked drill output into the Cogitator's REAL
  -- defines.inventory.chest. Read that same engine inventory for provenance
  -- and physical pickup. A legacy global accessor may be absent, or may
  -- resolve a different inventory; neither can authorize machine cargo.
  -- If a live station exposes get_inventory but its chest is unavailable,
  -- fail closed instead of falling through to an unrelated legacy store.
  if type(station.get_inventory)=="function" then
    local ids=defines and defines.inventory
    if not (ids and ids.chest) then return nil end
    local ok,inv=pcall(function()
      return station.get_inventory(ids.chest)
    end)
    if ok and valid(inv) and type(inv.insert)=="function"
        and type(inv.get_insertable_count)=="function" then return inv end
    return nil
  end
  -- Compatibility only for old non-engine fixtures lacking entity methods.
  local get=rawget(_G,"get_station_inventory")
  if type(get)~="function" then return nil end
  local ok,inv=pcall(get,station)
  if ok and valid(inv) and type(inv.insert)=="function"
      and type(inv.get_insertable_count)=="function" then return inv end
end
-- 0991: A drill output receipt is provenance, never spendable ore by itself.
-- The 0528 authority has already carried real chest output to this terminal
-- station. Only the paired terminal priest may physically debit that station.
-- The drill and receiver must still be real, connected, local engine entities.
-- 0999: engine acceptance can request one EXACT drill/receiver pair. A newer
-- receipt from a different drill must never satisfy that source's proof.
-- Normal gameplay omits the filters and retains the existing newest-first
-- physical receipt selection. Filters are identity checks, not item credits.
-- 1002: A persisted 0528 receipt names exact physical entity units. On
-- Factorio 2.0.77 an engine fixture retained a valid drill LuaEntity while
-- the global unit lookup returned nil. Re-resolve only missing handles by
-- scanning the terminal's ACTUAL surface for the SAME unit numbers. A nearby
-- unrelated machine/receiver can never authorize the recorded material.
local function receipt_entities_1002(terminal,proof)
  local drill=game.get_entity_by_unit_number(proof.drill_unit)
  local receiver=game.get_entity_by_unit_number(proof.receiver_unit)
  if valid(drill) and valid(receiver) then return drill,receiver end
  local surface=terminal.station.surface
  if not (surface and type(surface.find_entities_filtered)=="function") then
    return drill,receiver
  end
  local function locate(unit,kind,position,radius)
    local candidates=surface.find_entities_filtered{
      type=kind,position=position,radius=radius}
    for _,entity in pairs(candidates or {}) do
      if valid(entity) and entity.unit_number==unit
          and entity.surface==surface then return entity end
    end
    return nil
  end
  if not valid(receiver) then
    receiver=locate(proof.receiver_unit,{"container","logistic-container"},
      terminal.station.position,
      (tonumber(terminal.radius or terminal.base_radius) or 20)+1)
  end
  if not valid(drill) and valid(receiver) then
    drill=locate(proof.drill_unit,"mining-drill",receiver.position,8)
  end
  return drill,receiver
end

function M.drill_source_receipt_0991(terminal,mission,expected_drill_unit,expected_receiver_unit)
  if not (terminal and valid(terminal.station) and valid(terminal.priest)
      and mission and type(mission.need)=="string"
      and game and type(game.get_entity_by_unit_number)=="function") then
    return nil,"machine-source-entity-authority-unavailable"
  end
  local inv=station_inventory(terminal.station)
  if not inv or (count(inv,mission.need) or 0)<1 then
    return nil,"no-real-terminal-machine-stock"
  end
  local receipts=terminal.drill_output_receipts_0983
  if type(receipts)~="table" then return nil,"no-drill-output-receipt" end
  -- 1001: An exact-source engine refusal must identify the failed invariant,
  -- not hide distinct physical/receipt failures behind one generic label.
  -- This records no custody and does not loosen any acceptance predicate.
  local exact_refusal="no-matching-receipt"
  for i=#receipts,1,-1 do
    local proof=receipts[i]
    if type(proof)=="table"
        and (expected_drill_unit==nil or proof.drill_unit==expected_drill_unit)
        and (expected_receiver_unit==nil or proof.receiver_unit==expected_receiver_unit)
        and proof.item==mission.need
        and proof.station_unit==terminal.station.unit_number
        and proof.priest_unit==terminal.priest.unit_number
        and type(proof.count)=="number" and proof.count>=1
        and proof.count==math.floor(proof.count)
        and type(proof.source_before)=="number"
        and type(proof.source_after)=="number"
        and type(proof.station_before_0984)=="number"
        and type(proof.station_after_0984)=="number"
        and proof.source_after==proof.source_before-proof.count
        and proof.cargo_before_0984==proof.count
        and proof.cargo_after_0984==0
        and proof.station_after_0984==proof.station_before_0984+proof.count
        and proof.deposit_authority=="storage-role-deposit-exact-0686"
        and type(proof.pickup_tick)=="number"
        and type(proof.deposit_tick)=="number"
        and proof.pickup_tick<=proof.deposit_tick
        and proof.deposit_tick<=now()
        and type(proof.drill_unit)=="number"
        and type(proof.receiver_unit)=="number"
        and type(proof.relay_claimed_count_0991 or 0)=="number"
        and (proof.relay_claimed_count_0991 or 0)>=0
        and (proof.relay_claimed_count_0991 or 0)==math.floor(proof.relay_claimed_count_0991 or 0)
        and (proof.relay_claimed_count_0991 or 0)<proof.count then
      -- 0993: use the same physical connection predicate as the 0528
      -- pickup authority. A chest merely near a drill is not provenance:
      -- an occupied drop_target may point to a DIFFERENT receiver, and the
      -- old squared-distance <=2 admitted disconnected adjacent chests.
      local ok,drill,chest,drop,target=pcall(function()
        local source,receiver=receipt_entities_1002(terminal,proof)
        return source,receiver,source and source.valid and source.drop_position,
          source and source.valid and source.drop_target
      end)
      if ok and valid(drill) and valid(chest)
          and drill.unit_number==proof.drill_unit
          and chest.unit_number==proof.receiver_unit
          and drill.type=="mining-drill"
          and (chest.type=="container" or chest.type=="logistic-container")
          and drill.force==terminal.station.force
          and chest.force==terminal.station.force
          and drill.surface==terminal.station.surface
          and chest.surface==drill.surface
          and drop and (target==chest
            -- Factorio can expose the same live receiver through distinct
            -- LuaEntity handles. Unit identity + domain is authoritative;
            -- a different target unit must never be accepted as connected.
            or (valid(target) and target.unit_number==chest.unit_number
              and target.surface==chest.surface and target.force==chest.force)
            or (not valid(target) and dist2(drop,chest.position)<=0.51))
          and dist2(chest.position,terminal.station.position)
            <=(tonumber(terminal.radius or terminal.base_radius) or 20)^2 then
        return proof,i
      end
      if expected_drill_unit~=nil then
        if not ok then exact_refusal="live-entity-read-error"
        elseif not valid(drill) then exact_refusal="drill-entity-missing"
        elseif not valid(chest) then exact_refusal="receiver-entity-missing"
        elseif drill.unit_number~=proof.drill_unit then
          exact_refusal="drill-unit-mismatch"
        elseif chest.unit_number~=proof.receiver_unit then
          exact_refusal="receiver-unit-mismatch"
        elseif drill.type~="mining-drill" then exact_refusal="not-mining-drill"
        elseif chest.type~="container" and chest.type~="logistic-container" then
          exact_refusal="not-receiver-container"
        elseif drill.force~=terminal.station.force
            or chest.force~=terminal.station.force then
          exact_refusal="force-mismatch"
        elseif drill.surface~=terminal.station.surface
            or chest.surface~=drill.surface then
          exact_refusal="surface-mismatch"
        elseif not drop then exact_refusal="missing-drill-drop-position"
        elseif not (target==chest
            or (valid(target) and target.unit_number==chest.unit_number
              and target.surface==chest.surface and target.force==chest.force)
            or (not valid(target) and dist2(drop,chest.position)<=0.51)) then
          exact_refusal="receiver-disconnected"
        elseif dist2(chest.position,terminal.station.position)
            >(tonumber(terminal.radius or terminal.base_radius) or 20)^2 then
          exact_refusal="receiver-outside-terminal-radius"
        else exact_refusal="physical-connection-unverified" end
      end
    elseif expected_drill_unit~=nil and type(proof)=="table"
        and proof.drill_unit==expected_drill_unit
        and proof.receiver_unit==expected_receiver_unit then
      -- Preserve the original full receipt gate above. Explain the first
      -- failed material/custody field only for the explicitly requested source.
      if proof.item~=mission.need then exact_refusal="receipt-item-mismatch"
      elseif proof.station_unit~=terminal.station.unit_number then
        exact_refusal="receipt-station-mismatch"
      elseif proof.priest_unit~=terminal.priest.unit_number then
        exact_refusal="receipt-priest-mismatch"
      elseif type(proof.count)~="number" or proof.count<1
          or proof.count~=math.floor(proof.count) then
        exact_refusal="receipt-count-invalid"
      elseif type(proof.source_before)~="number"
          or type(proof.source_after)~="number"
          or proof.source_after~=proof.source_before-proof.count then
        exact_refusal="receiver-debit-unverified"
      elseif type(proof.station_before_0984)~="number"
          or type(proof.station_after_0984)~="number"
          or proof.station_after_0984~=proof.station_before_0984+proof.count then
        exact_refusal="station-deposit-unverified"
      elseif proof.cargo_before_0984~=proof.count
          or proof.cargo_after_0984~=0 then
        exact_refusal="carrier-custody-unverified"
      elseif proof.deposit_authority~="storage-role-deposit-exact-0686" then
        exact_refusal="deposit-authority-unverified"
      elseif type(proof.pickup_tick)~="number"
          or type(proof.deposit_tick)~="number"
          or proof.pickup_tick>proof.deposit_tick
          or proof.deposit_tick>now() then
        exact_refusal="receipt-tick-order-invalid"
      elseif type(proof.relay_claimed_count_0991 or 0)~="number"
          or (proof.relay_claimed_count_0991 or 0)<0
          or (proof.relay_claimed_count_0991 or 0)
            ~=math.floor(proof.relay_claimed_count_0991 or 0)
          or (proof.relay_claimed_count_0991 or 0)>=proof.count then
        exact_refusal="receipt-already-claimed-or-invalid"
      else exact_refusal="receipt-fields-unverified" end
    end
  end
  if expected_drill_unit~=nil then
    return nil,"no-verified-connected-expected-drill-output:"..exact_refusal
  end
  return nil,"no-verified-connected-drill-output"
end

-- A legacy "assignment" label can remain after a 0647 material request
-- becomes non-executable. It is NOT evidence that a live duty has ended:
-- require a real deposited relay receipt and no live combat, orders, or
-- physical custody. The canonical controller must walk the priest home
-- before the local station item can be picked up.
-- A dormant return label is not itself a live duty. A real movement lease
-- remains authoritative, and a counted physical relay receipt is required
-- before this worker can be asked to walk back to its own station.
-- Return the first authoritative live-duty refusal, not just a boolean.
-- This is read-only: the 0972 handoff may not cancel another owner's task.
local function no_live_relay_work(worker,allow_order_yield)
  if not (worker and valid(worker.station) and valid(worker.priest)) then
    return false,"invalid-pair"
  end
  local adopted_task_yield=false
  if allow_order_yield and worker.active_task_0285 and OrderQueue
      and type(OrderQueue.can_pause_uncommitted_relay_0974)=="function" then
    adopted_task_yield=OrderQueue.can_pause_uncommitted_relay_0974(
      worker,worker.infrastructure_recipe_request_0647)==true
  end
  for _,field in ipairs({
      "active_task","active_task_0285","current_task","emergency_craft",
      "active_acquisition_0333","direct_acquisition_task_0336",
      "inventory_transfer_custody_0687","construction_task_0338",
      "construction_task_0340","direct_acquisition_custody_0513",
      "construction_custody_0338","machine_logistics_custody_0528",
      "emergency_facility_feed_custody_0357","repair_pack_custody_0516",
      "consecration_refund_custody_0515","dead","recalling","deploying",
      "combat_target","repair_target","consecration_target",
      "construction_task","build_task","station_crafting_task_0337",
      "active_craft_0479","emergency_production_custody_0514",
      "direct_acquisition_movement_lock_0650","scavenge",
      "active_supply_request","supply_request","construction_request",
      "pending_construction","build_request"}) do
    if worker[field] and not (adopted_task_yield
        and (field=="active_task_0285" or (field=="active_task"
          and worker.active_task==worker.active_task_0285))) then
      return false,"live-duty:"..field
    end
  end
  if worker.station_expansion_0256
      and worker.station_expansion_0256.status~="complete" then
    return false,"unfinished-station-expansion"
  end
  local order=worker.order_queue_0469 and worker.order_queue_0469.current
  -- Even a paused foreign order owns the priest; an orphaned active-order
  -- pointer cannot be mistaken for idle after a process reload.
  if order or worker.active_order_0469 then
    if not (allow_order_yield and OrderQueue
        and type(OrderQueue.can_pause_uncommitted_relay_0974)=="function") then
      return false,"active-order"
    end
    local ok,why=OrderQueue.can_pause_uncommitted_relay_0974(
      worker,worker.infrastructure_recipe_request_0647)
    if not ok then return false,"active-order:"..tostring(why) end
  end
  return true,"no-live-work"
end
local function deferred_return_home_without_live_work(worker)
  if worker.mode~="returning" or not no_live_relay_work(worker)
      or not (MovementController
        and type(MovementController.request_status)=="function") then
    return false
  end
  local ok,status=pcall(MovementController.request_status,worker)
  if not (ok and type(status)=="table" and status.active==false
      and (status.status=="missing-request" or status.status=="expired")) then
    return false
  end
  local request=worker.movement_request_0418
  return not(request and tonumber(request.expires_tick)
    and request.expires_tick>=now())
end
local function deferred_assignment_without_live_work(worker)
  if worker.mode~="assignment" then return false,"not-assignment" end
  local pending=worker.infrastructure_recipe_request_0647
  if not(type(pending)=="table"
      and type(pending.item)=="string" and pending.item~=""
      and type(pending.missing)=="string" and pending.missing~=""
      and valid(worker.station) and valid(worker.priest)) then
    return false,"missing-uncommitted-0647-request"
  end
  -- The 0469 queue may yield only its exact uncommitted material order.
  local clear,why=no_live_relay_work(worker,true)
  if not clear then return false,why end
  -- A retained 0285 assignment is not permission to override live navigation.
  if not (MovementController and type(MovementController.request_status)=="function") then
    return false,"canonical-movement-owner-unavailable"
  end
  local ok,status=pcall(MovementController.request_status,worker)
  if not(ok and type(status)=="table" and status.active==false
      and (status.status=="missing-request" or status.status=="expired")) then
    return false,"canonical-movement:"..tostring(status and status.status)
  end
  local request=worker.movement_request_0418
  if request and tonumber(request.expires_tick) and request.expires_tick>=now() then
    return false,"pair-movement-lease-active"
  end
  return true,"uncommitted-assignment-verified"
end
-- 0972: A completed 0513 direct-mining task can leave its last travel mode
-- behind while 0647 still has an UNCOMMITTED ingredient request. The real
-- engine showed this exact state on the Senior relay: no active direct task,
-- no movement lease, no custody, and one counted ore item waiting at home.
-- Only a verified receipt permits a new physical walk; the recipe request
-- remains intact for ordinary infrastructure work after the relay.
-- 0981: 0318 may retain the exact same adopted assignment in BOTH task
-- slots while 0513 leaves a working/failed label behind. A live 0513 task,
-- movement, foreign task or custody still refuses; only 0469 may pause it.
-- The engine's Senior can retain this travel label after an uncommitted
-- 0647 request. Expose which independent owner still holds it; never infer
-- permission to move from the label or the courier's reservation alone.
local function dormant_direct_travel_without_live_work(worker)
  if not worker or (worker.mode~="travelling-to-direct-acquisition"
      and worker.mode~="direct-acquisition-working"
      and worker.mode~="direct-acquisition-failed") then
    return false,"not-direct-travel"
  end
  local clear,why=no_live_relay_work(worker,true)
  if not clear then return false,why end
  local pending=worker.infrastructure_recipe_request_0647
  if not(type(pending)=="table" and type(pending.item)=="string"
      and pending.item~="" and type(pending.missing)=="string"
      and pending.missing~="") then
    return false,"missing-uncommitted-0647-request"
  end
  if (worker.requested_item and worker.requested_item~=pending.missing)
      or (worker.logistic_requested_item
        and worker.logistic_requested_item~=pending.missing) then
    return false,"foreign-ingredient-request"
  end
  local gate=worker.local_infrastructure_gate_0640
  if gate and (type(gate)~="table"
      or (gate.item~=pending.item and gate.item~=pending.missing)) then
    return false,"foreign-infrastructure-gate"
  end
  local expedition=worker.direct_acquisition_expedition_0513
  if type(expedition)=="table" and expedition.authorized==true
      and (not expedition.expires_tick or expedition.expires_tick>=now()) then
    return false,"active-direct-expedition"
  end
  if not(DirectAcquisition
      and type(DirectAcquisition.current_direct_task)=="function"
      and MovementController
      and type(MovementController.request_status)=="function") then
    return false,"canonical-owner-unavailable"
  end
  local inspected,task=pcall(DirectAcquisition.current_direct_task,worker)
  if not inspected then return false,"direct-task-owner-probe-error" end
  if task~=nil then return false,"direct-task-owner-still-active" end
  local ok,status=pcall(MovementController.request_status,worker)
  if not(ok and type(status)=="table") then
    return false,"movement-owner-probe-error"
  end
  if status.active~=false
      or (status.status~="missing-request" and status.status~="expired") then
    return false,"canonical-movement:"..tostring(status.status)
  end
  local request=worker.movement_request_0418
  if request and tonumber(request.expires_tick)
      and request.expires_tick>=now() then
    return false,"pair-movement-lease-active"
  end
  return true,"dormant-direct-verified"
end
-- Read-only production probe used by the existing engine harness and
-- regressions. No recipe, custody, movement, or inventory is modified.
function M.probe_dormant_direct_relay_0973(worker)
  return dormant_direct_travel_without_live_work(worker)
end
local function available_for_courier(worker,allow_deferred_assignment,allow_return_home,allow_dormant_direct)
  -- A real 0647 recipe wait can leave the pair mode non-idle despite having
  -- no active executable work. The ore courier is meant to supply the very
  -- absent material; treating that *mode label alone* as a perpetual live
  -- duty deadlocks the remote resource objective. Preserve the complete
  -- recipe request for later resumption; never waive any active task or held
  -- physical custody (checked independently below).
  local pending=worker.infrastructure_recipe_request_0647
  local deferred_material=worker.mode=="infrastructure-material-acquisition-0647"
    and type(pending)=="table" and type(pending.missing)=="string"
    and #pending.missing>0
  -- A completed miner may remain labelled "returning" while the 0510
  -- dispatcher withholds new legacy work for a reserved courier. Permit
  -- handoff only after the actual priest returns physically to its station.
  -- Every independent active-task and custody check below still applies.
  local returned_home=worker.mode=="returning"
    and valid(worker.station) and valid(worker.priest)
    and dist2(worker.priest.position,worker.station.position)<=M.reach_sq
  local deferred_assignment,assignment_reason=false,nil
  if allow_deferred_assignment==true then
    deferred_assignment,assignment_reason=
      deferred_assignment_without_live_work(worker)
  end
  -- A prior "returning" label can persist after its movement request
  -- expires while the 0837 reservation blocks ordinary scheduling. Only a
  -- counted receipt, absent live work, and absent active movement permit a
  -- new physical walk to the priest's OWN station. Ore is never debited here.
  local dormant_return=allow_return_home==true
    and deferred_return_home_without_live_work(worker)
  local dormant_direct,dormant_reason=false,nil
  if allow_dormant_direct==true then
    dormant_direct,dormant_reason=dormant_direct_travel_without_live_work(worker)
  end
  if (worker.mode and worker.mode~="idle" and not deferred_material
      and not returned_home and not deferred_assignment
      and not dormant_return and not dormant_direct)
      or (worker.active_task and not (deferred_assignment or dormant_direct))
      or worker.current_task
      or worker.emergency_craft or worker.active_acquisition_0333
      or worker.direct_acquisition_task_0336
      or worker.inventory_transfer_custody_0687
      or worker.construction_task_0338 or worker.construction_task_0340 then
    return false,"upstream-priest-has-existing-duty",
      dormant_reason or assignment_reason
  end
  local expansion=worker.station_expansion_0256
  -- An old, successfully completed station expansion is history, not an
  -- active physical custody claim. An unfinished/failed/unknown expansion
  -- must still retain ownership until its station item is accounted for.
  if worker.direct_acquisition_custody_0513
      or worker.construction_custody_0338
      or worker.machine_logistics_custody_0528
      or worker.emergency_facility_feed_custody_0357
      or worker.repair_pack_custody_0516
      or worker.consecration_refund_custody_0515
      or (expansion and expansion.status~="complete") then
    return false,"upstream-priest-has-existing-custody"
  end
  return true
end
-- The only 0838 handoff allowed to use a dormant "assignment" mode:
-- a completed prior physical hop, the exact pending priest and a still-present
-- real ore item reserved at that priest's own station. A ledger alone cannot
-- authorize pickup; no task or inventory is modified by this check.
local function receipt_authorizes_deferred_assignment(state,hop,worker)
  if not(state.phase=="first-hop-delivered"
      and valid(worker.station) and valid(worker.priest)
      and state.pending_upstream_station_unit==worker.station.unit_number
      and state.pending_upstream_priest_unit==worker.priest.unit_number
      and state.delivered_station_unit==worker.station.unit_number
      and state.station_custody_unit==worker.station.unit_number
      and state.delivered_count==1 and state.inventory==nil
      and state.receipt_hop==hop and state.hops_completed==hop
      and type(state.receipt_destination_before)=="number"
      and state.receipt_destination_after==state.receipt_destination_before+1) then
    return false
  end
  local inv=station_inventory(worker.station)
  local held=inv and count(inv,state.item)
  return held~=nil and held>=1
end
function M.worker_reserved(worker)
  if not (worker and valid(worker.station) and valid(worker.priest)) then return false end
  local assignment=worker.remote_resource_assignment_0820
  -- The Magos is the root of the route, not a subordinate assignment.
  local magos=assignment and pair(assignment.root_station_unit)
    or (worker.resource_expansion_0259 and worker)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local state=mission and mission.return_courier_0837
  if not (mission and mission.status=="reached-resource" and state) then
    return false
  end
  local route=Chain.return_route(magos)
  if not route then return false end
  -- A counted route reserves every FUTURE relay priest before delivery.
  -- Otherwise the arriving ore can trigger an unrelated new assignment
  -- before its next courier duty has a chance to reserve that receiver.
  -- Never cancel existing work or seize physical inventory.
  if state.phase~="magos-delivered" and state.phase~="custody-blocked" then
    for i=(state.hop_index or 1)+1,#route do
      if route[i]==worker.station.unit_number then return true end
    end
  end
  -- A waiting courier reserves only FUTURE scheduling. Existing tasks and
  -- physical custody must finish normally before the priest may move.
  if state.phase=="awaiting-terminal-duty"
      or (state.phase=="first-hop-delivered"
          and state.pending_upstream_station_unit) then
    if state.phase=="awaiting-terminal-duty" then
      return route[1]==worker.station.unit_number
        and state.source_station_unit==worker.station.unit_number
        and state.carrier_priest_unit==worker.priest.unit_number
    end
    local hop=state.hop_index or 1
    return route[hop]==state.source_station_unit
      and route[hop+1]==worker.station.unit_number
      and state.pending_upstream_station_unit==worker.station.unit_number
      and state.pending_upstream_priest_unit==worker.priest.unit_number
  end
  return state.phase~="first-hop-delivered" and state.phase~="magos-delivered"
    and state.source_station_unit==worker.station.unit_number
    and state.carrier_priest_unit==worker.priest.unit_number
end
-- 0992: a completed 0528 physical deposit must not be spent by generic
-- logistics before the terminal priest can walk home to collect it.
-- Reserve only observed, still-unclaimed real stock backed by a live connected
-- drill receipt and the verified ranked route. This does not transfer, mint,
-- or claim any item; the 0991 pickup remains the sole physical debit.
function M.machine_source_reserved_0992(worker,item)
  if not (worker and valid(worker.station) and valid(worker.priest)
      and type(item)=="string") then return 0 end
  local assignment=worker.remote_resource_assignment_0820
  local magos=assignment and pair(assignment.root_station_unit)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not (mission and mission.status=="reached-resource"
      and mission.need==item
      and mission.current_station_unit==worker.station.unit_number) then
    return 0
  end
  local state=mission.return_courier_0837
  -- 0996: a completed natural return does not cancel custody of NEW
  -- drill output. The service may rearm only after validating the previous
  -- physical delivery ledger. Active natural cargo and quarantine stay closed.
  if state and (state.phase=="custody-blocked"
      or (state.phase~="awaiting-terminal-duty"
        and state.phase~="magos-delivered"
        and state.source_kind_0991~="drill-output")) then return 0 end
  local route=Chain.return_route(magos)
  if not (route and route[1]==worker.station.unit_number) then return 0 end
  local proof=M.drill_source_receipt_0991(worker,mission)
  if not proof then return 0 end
  local inv=station_inventory(worker.station)
  local stock=inv and count(inv,item)
  if not (stock and stock>=1) then return 0 end
  return math.min(stock,proof.count-(proof.relay_claimed_count_0991 or 0))
end
-- Reserve real machine output at its terminal and one ALREADY DEPOSITED
-- physical relay item at its exact upstream station. Never count either
-- ledger as extra ore or as a remote inventory transfer.
function M.reserved_at_station(worker,item)
  if not (worker and valid(worker.station) and valid(worker.priest)
      and type(item)=="string") then return 0 end
  local machine_reserved=M.machine_source_reserved_0992(worker,item)
  if machine_reserved>0 then return machine_reserved end
  local assignment=worker.remote_resource_assignment_0820
  local magos=assignment and pair(assignment.root_station_unit)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local state=mission and mission.return_courier_0837
  if not (mission and mission.status=="reached-resource" and state
      and state.item==item and state.delivered_count==1
      and state.delivered_station_unit==worker.station.unit_number) then
    return 0
  end
  local phase=state.phase
  local awaiting=phase=="first-hop-delivered"
    or phase=="to-upstream-pickup" or phase=="upstream-pickup-debit"
  local explicit=state.station_custody_unit==worker.station.unit_number
  -- Older saves have no explicit station_custody_unit: infer only from
  -- a verified delivery awaiting its next real pickup.
  if (explicit and (awaiting or phase=="custody-blocked"))
      or (state.station_custody_unit==nil and awaiting) then return 1 end
  return 0
end
function M.spendable_station_item(worker,item,observed)
  local n=math.max(0,math.floor(tonumber(observed) or 0))
  return math.max(0,n-M.reserved_at_station(worker,item))
end

-- Resume the exact paused planning order only after a real destination
-- inventory receipt. This also reconciles a process reload between the
-- physical deposit and the subsequent order-queue handoff.
local function resume_delivered_order(state,route)
  if not (state and (state.phase=="first-hop-delivered"
      or state.phase=="magos-delivered")
      and OrderQueue
      and type(OrderQueue.resume_after_resource_relay_0974)=="function") then
    return
  end
  local hop=state.hop_index
  if not (type(hop)=="number" and hop>=1 and hop<#route
      and state.receipt_hop==hop and state.hops_completed==hop
      and state.delivered_count==1 and state.inventory==nil
      and state.delivered_station_unit==route[hop+1]
      and state.receipt_destination_after==state.receipt_destination_before+1) then
    return
  end
  local source,dest=pair(route[hop]),pair(route[hop+1])
  local inv=dest and valid(dest.station) and station_inventory(dest.station)
  if not (source and valid(source.priest)
      and source.priest.unit_number==state.carrier_priest_unit
      and inv and (count(inv,state.item) or 0)>=1) then return end
  pcall(OrderQueue.resume_after_resource_relay_0974,source)
end
function M.service(magos)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not (mission and mission.status=="reached-resource"
      and valid(magos.station) and valid(magos.priest)
      and magos.station.unit_number==mission.root_station_unit) then
    return false,"resource-route-not-ready"
  end
  local route,why=Chain.return_route(magos)
  if not route then
    -- A pending reservation has no material custody; do not indefinitely
    -- block scheduling if the physical route disappears before dispatch.
    local pending=mission.return_courier_0837
    if pending and pending.phase=="awaiting-terminal-duty"
        and pending.inventory==nil then
      mission.return_courier_0837=nil
    end
    return false,why
  end
  if #route<2 then return false,"no-physical-upstream-hop" end
  local state=mission.return_courier_0837
  -- 0996: the original natural-ore delivery must not permanently lock the
  -- courier when a NEW, physically deposited machine receipt is available.
  -- Never erase a completed ledger unless every previous hop is still
  -- verifiable; this transition creates no item and does not move cargo.
  if state and state.phase=="magos-delivered" then
    local fresh=M.drill_source_receipt_0991(pair(route[1]),mission)
    if fresh then
      local ledger_ok,ledger_reason=M.validate_receipts_0982(state,route)
      if not (type(state.receipts_0982)=="table" and ledger_ok
          and state.hops_completed==#route-1
          and state.receipt_hop==#route-1
          and state.delivered_station_unit==route[#route]
          and state.delivered_count==1 and state.quantity==1
          and state.inventory==nil and state.item==mission.need
          and (mission.delivered_to_magos_count or 0)>=1) then
        return false,"completed-return-rearm-unverified:"..tostring(ledger_reason)
      end
      -- Keep primitive-only physical receipts across process reload, not
      -- another material credit. The new carrier starts empty and must
      -- locally debit the terminal's actual inventory.
      local history=mission.completed_return_receipts_0996 or {}
      local snapshot={
        item=state.item,
        source_kind_0991=state.source_kind_0991 or "natural-ore",
        magos_station_unit=route[#route],
        completed_tick=state.completed_tick,
        receipts_0982={},
      }
      for i,entry in ipairs(state.receipts_0982) do
        snapshot.receipts_0982[i]={
          hop=entry.hop,source_station_unit=entry.source_station_unit,
          destination_station_unit=entry.destination_station_unit,
          carrier_priest_unit=entry.carrier_priest_unit,
          item=entry.item,quantity=entry.quantity,
          destination_before=entry.destination_before,
          destination_after=entry.destination_after,tick=entry.tick,
        }
      end
      history[#history+1]=snapshot
      while #history>16 do table.remove(history,1) end
      mission.completed_return_receipts_0996=history
      mission.return_courier_0837=nil
      state=nil
    end
  end
  if not state then
    local terminal=pair(route[1])
    if not (terminal and valid(terminal.priest)
        and terminal.priest.unit_number) then
      return false,"terminal-priest-missing"
    end
    -- Persist a future-work reservation before waiting for an existing duty.
    -- The governor may stop assigning NEW work, but this code never cancels
    -- an active task, takes its inventory, or moves its priest.
    state={
      phase="awaiting-terminal-duty",source_station_unit=route[1],
      destination_station_unit=route[2],
      carrier_priest_unit=terminal.priest.unit_number,
      item=mission.need,quantity=0,receipts_0982={},
      started_tick=now(),updated_tick=now(),next_tick=now(),
    }
    mission.return_courier_0837=state
  end
  if state.phase=="awaiting-terminal-duty" then
    local terminal=pair(route[1])
    if not (terminal and valid(terminal.station) and valid(terminal.priest)
        and terminal.priest.unit_number==state.carrier_priest_unit
        and terminal.station.unit_number==state.source_station_unit) then
      -- No material was acquired; release this stale future-work lease.
      mission.return_courier_0837=nil
      return false,"terminal-priest-changed-before-courier"
    end
    local free,reason=available_for_courier(terminal)
    if not free then
      return false,reason=="upstream-priest-has-existing-duty"
        and "terminal-priest-has-existing-duty"
        or "terminal-priest-has-existing-custody"
    end
    local receipt,index=M.drill_source_receipt_0991(terminal,mission)
    if receipt then
      state.source_kind_0991="drill-output"
      state.drill_receipt_index_0991=index
      state.drill_receipt_deposit_tick_0991=receipt.deposit_tick
      state.drill_receipt_drill_unit_0991=receipt.drill_unit
      state.drill_receipt_receiver_unit_0991=receipt.receiver_unit
      state.phase="to-upstream-pickup"
    else
      state.phase="to-natural-ore"
    end
    state.next_tick=now()
    state.updated_tick=now()
  end
  local receipts_ok,receipts_reason=M.validate_receipts_0982(state,route)
  if not receipts_ok then
    return blocked(state,"physical-hop-receipt-ledger-invalid:"..receipts_reason)
  end
  if state.phase=="magos-delivered" then
    resume_delivered_order(state,route)
    return false,"natural-ore-already-delivered-to-magos"
  end
  if state.phase=="custody-blocked" then
    return false,state.last_reason or "custody-blocked"
  end
  local hop=state.hop_index or 1 -- prior first-hop saves
  if hop<1 or hop>=#route or hop~=math.floor(hop)
      or state.source_station_unit~=route[hop]
      or state.destination_station_unit~=route[hop+1]
      or state.item~=mission.need then
    return blocked(state,"return-route-changed-during-custody")
  end
  if state.phase=="first-hop-delivered" then
    resume_delivered_order(state,route)
    -- A committed deposit cannot be debited twice. The next paired priest
    -- must take one real item from its own station, never from a remote child.
    if state.delivered_station_unit~=route[hop+1]
        or state.delivered_count~=1 or state.inventory~=nil then
      return blocked(state,"prior-upstream-delivery-not-verifiable")
    end
    local next_hop=hop+1
    if next_hop>=#route then
      return blocked(state,"delivered-phase-at-terminal-route")
    end
    local next_worker=pair(route[next_hop])
    if not (next_worker and valid(next_worker.station)
        and valid(next_worker.priest)
        and next_worker.priest.unit_number) then
      return false,"next-upstream-priest-unavailable"
    end
    -- Claim the next worker for FUTURE scheduling while its current duty
    -- completes. Never withdraw the ore or move the priest until idle.
    state.pending_upstream_station_unit=next_worker.station.unit_number
    state.pending_upstream_priest_unit=next_worker.priest.unit_number
    local receipt=receipt_authorizes_deferred_assignment(state,hop,next_worker)
    local deferred_assignment=next_worker.mode=="assignment" and receipt
    local return_home=next_worker.mode=="returning" and receipt
    local dormant_direct=(next_worker.mode=="travelling-to-direct-acquisition"
      or next_worker.mode=="direct-acquisition-working"
      or next_worker.mode=="direct-acquisition-failed") and receipt
    local free,reason,detail=available_for_courier(next_worker,deferred_assignment,
      return_home,dormant_direct)
    if not free then
      -- Primitive-only persisted refusal: truthful engine diagnosis without
      -- preempting the 0513/0640 owner or touching the real deposited ore.
      state.last_upstream_handoff_reason=detail or reason
      state.last_upstream_handoff_tick=now()
      return false,reason
    end
    state.last_upstream_handoff_reason=nil
    local source_inv=station_inventory(next_worker.station)
    if not source_inv or (count(source_inv,state.item) or 0)<1 then
      return false,"previously-delivered-ore-not-in-upstream-storage"
    end
    -- 0975: includes an otherwise dormant "assignment" material order.
    -- An active 0469 planning order must be explicitly paused by its own
    -- authority, after the counted receipt and real inventory readback.
    -- The ore remains in station custody until the priest walks home.
    if (dormant_direct or deferred_assignment) and OrderQueue
        and type(OrderQueue.pause_uncommitted_relay_0974)=="function" then
      local ok,why=OrderQueue.pause_uncommitted_relay_0974(
        next_worker,next_worker.infrastructure_recipe_request_0647)
      if not ok then
        state.last_upstream_handoff_reason="order-yield:"..tostring(why)
        state.last_upstream_handoff_tick=now()
        return false,"upstream-priest-has-existing-duty"
      end
    end
    state.pending_upstream_station_unit=nil
    state.pending_upstream_priest_unit=nil
    state.hop_index=next_hop
    state.source_station_unit=route[next_hop]
    state.destination_station_unit=route[next_hop+1]
    state.carrier_priest_unit=next_worker.priest.unit_number
    state.phase="to-upstream-pickup"
    state.next_tick=now()
    state.updated_tick=now()
    state.last_reason="next-upstream-priest-reserved-for-local-pickup"
    return true,"next-physical-upstream-hop-reserved"
  end
  local source,dest=pair(state.source_station_unit),pair(state.destination_station_unit)
  if not (source and dest and valid(source.station) and valid(source.priest)
      and valid(dest.station) and valid(dest.priest)
      and source.priest.unit_number==state.carrier_priest_unit
      and source.station.surface==dest.station.surface
      and source.station.force==dest.station.force
      and source.station.unit_number==route[hop]
      and (hop~=1 or source.station.unit_number==mission.current_station_unit)) then
    return blocked(state,"physical-route-or-carrier-identity-changed")
  end
  if now()<(state.next_tick or 0) then return false,"courier-interval" end
  state.next_tick=now()+M.interval
  state.updated_tick=now()
  if state.phase=="to-upstream-pickup" then
    if hop==1 and state.source_kind_0991=="drill-output" then
      local proof,index=M.drill_source_receipt_0991(source,mission)
      if not (proof and index==state.drill_receipt_index_0991
          and proof.deposit_tick==state.drill_receipt_deposit_tick_0991
          and proof.drill_unit==state.drill_receipt_drill_unit_0991
          and proof.receiver_unit==state.drill_receipt_receiver_unit_0991) then
        return blocked(state,"drill-source-receipt-or-physical-connection-changed")
      end
    end
    if dist2(source.priest.position,source.station.position)>M.reach_sq then
      local ok,movement=move(source,source.station.position,"resource-return-upstream-pickup-0953")
      return false,ok and "walking-to-upstream-pickup" or movement
    end
    local source_inv=station_inventory(source.station)
    if not source_inv then return false,"upstream-pickup-inventory-unavailable" end
    local before=count(source_inv,state.item)
    if not before or before<1 then
      return false,"previously-delivered-ore-not-in-upstream-storage"
    end
    if state.inventory~=nil then
      return blocked(state,"unexpected-prior-courier-inventory")
    end
    if not (game and type(game.create_inventory)=="function") then
      return false,"engine-courier-inventory-unavailable"
    end
    local ok,bag=pcall(function() return game.create_inventory(1) end)
    if not (ok and valid(bag) and count(bag,state.item)==0
        and count(bag)==0) then
      return false,"engine-courier-inventory-allocation-failed"
    end
    -- Persist the empty hold before mutating real station stock.
    state.inventory=bag
    state.pickup_source_before=before
    state.phase="upstream-pickup-debit"
  end
  if state.phase=="upstream-pickup-debit" then
    local source_inv=station_inventory(source.station)
    if not source_inv then return blocked(state,"upstream-pickup-source-lost") end
    local before=state.pickup_source_before
    local held,total=count(state.inventory,state.item),count(state.inventory)
    local current=count(source_inv,state.item)
    if not (before and held and total and current) then
      return blocked(state,"upstream-pickup-inventory-unobservable")
    end
    if held==0 and total==0 and current==before then
      pcall(function() source_inv.remove{name=state.item,count=1} end)
      current=count(source_inv,state.item)
    end
    if held==0 and total==0 and current==before-1 then
      pcall(function() state.inventory.insert{name=state.item,count=1} end)
      held,total=count(state.inventory,state.item),count(state.inventory)
    end
    if held~=1 or total~=1 or current~=before-1 then
      -- A partial or ambiguous physical debit is quarantined, not repeated.
      return blocked(state,"upstream-pickup-custody-ambiguous")
    end
    if hop==1 and state.source_kind_0991=="drill-output"
        and not state.drill_receipt_claimed_0991 then
      local proof=source.drill_output_receipts_0983
        and source.drill_output_receipts_0983[state.drill_receipt_index_0991]
      if not (proof and proof.deposit_tick==state.drill_receipt_deposit_tick_0991
          and proof.drill_unit==state.drill_receipt_drill_unit_0991
          and proof.receiver_unit==state.drill_receipt_receiver_unit_0991
          and (proof.relay_claimed_count_0991 or 0)<proof.count) then
        return blocked(state,"drill-source-receipt-changed-after-physical-debit")
      end
      proof.relay_claimed_count_0991=(proof.relay_claimed_count_0991 or 0)+1
      state.drill_receipt_claimed_0991=true
    end
    state.quantity=1
    state.station_custody_unit=nil -- real ore now in engine-owned carrier
    state.phase="carrying"
    state.last_reason="one-physical-upstream-item-debited-into-courier-hold"
    return true,"physical-upstream-item-picked-up"
  end
  if state.phase=="to-natural-ore" or state.phase=="mining" then
    local ore,reason=natural_ore(source,mission)
    if not ore then return false,reason end
    if dist2(source.priest.position,ore.position)>M.reach_sq then
      local ok,movement=move(source,ore.position,"resource-return-natural-ore-0953")
      return false,ok and "walking-to-natural-ore" or movement
    end
    if not state.inventory then
      if not (game and type(game.create_inventory)=="function") then
        return false,"engine-courier-inventory-unavailable"
      end
      local ok,bag=pcall(function() return game.create_inventory(1) end)
      if not (ok and valid(bag) and count(bag,state.item)==0) then
        return false,"engine-courier-inventory-allocation-failed"
      end
      state.inventory=bag
      state.phase="mining"
      state.ore_unit=ore.unit_number
      state.ore_amount_before=ore.amount
    end
    if count(state.inventory,state.item)==0 then
      if state.ore_unit~=ore.unit_number
          or ore.amount~=state.ore_amount_before then
        return blocked(state,"ore-changed-before-physical-mine")
      end
      -- The actual LuaEntity.mine writes the product into persistent
      -- LuaInventory; no Lua quantity is used to fabricate ore.
      pcall(function() ore.mine{inventory=state.inventory} end)
    end
    local held,total=count(state.inventory,state.item),count(state.inventory)
    if not held or held<1 or total~=held then
      return blocked(state,"physical-ore-mine-produced-no-verifiable-item")
    end
    if held~=1 then return blocked(state,"first-hop-requires-single-item-stack") end
    if valid(ore) and not (ore.amount<state.ore_amount_before) then
      return blocked(state,"ore-source-did-not-decrement")
    end
    state.quantity=held
    state.phase="carrying"
    state.last_reason="one-real-ore-item-mined-into-engine-inventory"
    return true,"physical-ore-mined"
  end
  if state.phase~="carrying" then
    return blocked(state,"unknown-courier-phase")
  end
  if count(state.inventory,state.item)~=state.quantity
      or state.quantity~=1 then
    return blocked(state,"carried-ore-custody-count-changed")
  end
  if dist2(source.priest.position,dest.station.position)>M.reach_sq then
    local ok,movement=move(source,dest.station.position,"resource-return-upstream-delivery-0953")
    return false,ok and "walking-to-upstream-station" or movement
  end
  local dest_inv=station_inventory(dest.station)
  if not dest_inv then return false,"upstream-real-inventory-unavailable" end
  local ok_capacity,capacity=pcall(function()
    return dest_inv.get_insertable_count(state.item)
  end)
  if not ok_capacity or capacity<state.quantity then
    return false,"upstream-inventory-full"
  end
  local before=count(dest_inv,state.item)
  if before==nil then return false,"upstream-inventory-count-unavailable" end
  if state.receipts_0982 and #state.receipts_0982~=hop-1 then
    return blocked(state,"physical-hop-receipt-sequence-invalid")
  end
  pcall(function()
    state.inventory.remove({name=state.item,count=state.quantity})
  end)
  if count(state.inventory,state.item)~=0 then
    return blocked(state,"carrier-physical-debit-unverifiable")
  end
  pcall(function()
    dest_inv.insert({name=state.item,count=state.quantity})
  end)
  if count(dest_inv,state.item)~=before+state.quantity then
    -- A refused insert is refunded to the original physical carrier hold.
    -- Ambiguous post-mutation callbacks are quarantined, never credited.
    pcall(function()
      state.inventory.insert({name=state.item,count=state.quantity})
    end)
    if count(state.inventory,state.item)==state.quantity
        and count(dest_inv,state.item)==before then
      return false,"upstream-insertion-refused-refunded-to-carrier"
    end
    return blocked(state,"upstream-transfer-custody-ambiguous")
  end
  -- Persist an auditable, real destination receipt delta for this hop.
  -- Background autonomous production at other stations is allowed.
  state.receipt_hop=hop
  state.receipt_destination_before=before
  state.receipt_destination_after=before+state.quantity
  if state.receipts_0982 then
    state.receipts_0982[#state.receipts_0982+1]={
      hop=hop,source_station_unit=source.station.unit_number,
      destination_station_unit=dest.station.unit_number,
      carrier_priest_unit=source.priest.unit_number,
      item=state.item,quantity=state.quantity,
      destination_before=before,destination_after=before+state.quantity,
      tick=now(),
    }
  end
  if valid(state.inventory) then
    pcall(function() state.inventory.destroy() end)
  end
  state.inventory=nil
  state.delivered_count=state.quantity
  state.delivered_station_unit=dest.station.unit_number
  state.station_custody_unit=hop<#route-1 and dest.station.unit_number or nil
  state.hops_completed=hop
  state.completed_tick=now()
  if hop==#route-1 then
    state.phase="magos-delivered"
    mission.delivered_to_magos_count=(mission.delivered_to_magos_count or 0)+1
    state.last_reason=state.source_kind_0991=="drill-output"
      and "one-machine-produced-ore-item-physically-received-by-magos"
      or "one-natural-ore-item-physically-received-by-magos"
    resume_delivered_order(state,route)
    return true,state.source_kind_0991=="drill-output"
      and "counted-machine-ore-received-by-magos"
      or "counted-natural-ore-received-by-magos"
  end
  state.phase="first-hop-delivered"
  state.last_reason="one-real-ore-item-physically-delivered-to-upstream-station"
  resume_delivered_order(state,route)
  return true,"first-physical-upstream-hop-delivered"
end
_G.TechPriestsResourceReturnCourier0837=M
return M
