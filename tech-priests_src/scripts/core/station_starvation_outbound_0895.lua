-- Method I 0895: the first outbound transfer after four physically mined depots.
-- The Magos takes ONE real Senior item from its protected engine inventory
-- into the existing 0824 priest-carried inventory. No build is credited here.
-- 0896: a vanished 0256-owned construction ghost may be restored ONLY after
-- four-depot, original-priest, mission and custody authority is verified.
local Audit=require("scripts.core.station_starvation_rebuild_0867")
local Depot=require("scripts.core.station_starvation_depot_0852")
local Cargo=require("scripts.core.station_cargo_0824")
local Relocation=require("scripts.core.station_relocation_0823")
local M={version="0.1.674-dev.0900"}
local ITEM="senior-cogitator-station"
local KEYS={"reversal_stage_0851","reversal_stage_0853",
  "reversal_stage_0854","reversal_stage_0855"}
local function valid(x) return x and x.valid end
local function count(inv,item)
  if not(valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function()return inv.get_item_count(item)end)
  return ok and type(n)=="number" and n or nil
end
local function dist2(a,b)
  if not(a and b) then return math.huge end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
-- A real, exact-writ ghost may be backward OR outside the current Magos
-- command radius after recovery. Neither geometry is build authority.
-- Never count such a ghost as progress or adopt a foreign ghost.
-- 0904: two LuaObject wrappers for the same Factorio force/surface can
-- differ by reference. Compare authoritative engine indices when available;
-- never accept matching names with different indices or missing identity.
local function same_engine_domain_0904(observed,expected)
  if not(observed and expected) then return false end
  if observed==expected then return true end
  return type(observed.index)=="number"
    and type(expected.index)=="number"
    and observed.index==expected.index
end
local function owned_ghost(magos,rec,ghost)
  local p=rec.ghost_position
  return type(p)=="table" and type(p.x)=="number"
    and type(p.y)=="number" and rec.ghost_unit
    and rec.station_item==ITEM and rec.station_entity==ITEM
    and valid(ghost) and ghost.name=="entity-ghost"
    and ghost.ghost_name==ITEM and ghost.unit_number==rec.ghost_unit
    and same_engine_domain_0904(ghost.force,magos.station.force)
    and same_engine_domain_0904(ghost.surface,magos.station.surface)
    and dist2(ghost.position,p)<0.01
end
local function ghost_geometry(magos,rec)
  local radius=tonumber(magos.radius)
  if type(_G.refresh_pair_radius)=="function" then
    local ok,r=pcall(_G.refresh_pair_radius,magos)
    if ok and tonumber(r) then radius=tonumber(r) end
  end
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local p=rec.ghost_position
  return radius and radius>0 and mission and mission.target
      and dist2(magos.station.position,p)<=radius^2,
    mission and mission.target
      and dist2(p,mission.target)<dist2(magos.station.position,mission.target)
end
local function ghost_for(magos,rec,ghost)
  if not owned_ghost(magos,rec,ghost) then return nil end
  local within,forward=ghost_geometry(magos,rec)
  return within and forward and ghost or nil
end
local function misplaced_owned_ghost(magos,rec,ghost)
  if not owned_ghost(magos,rec,ghost) then return false end
  local within,forward=ghost_geometry(magos,rec)
  return not within or not forward
end

local function stage_identity(magos,rec,state,ghost,allow_missing_ghost)
  local tp=storage and storage.tech_priests
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local plan=rec and rec.reversal_plan_0850
  if not(type(state)=="table" and type(state.target)=="table"
      and type(state.ghost_position)=="table"
      and mission and type(mission.target)=="table"
      and plan and type(plan.target)=="table"
      and mission.target.x==plan.target.x
      and mission.target.y==plan.target.y
      and state.target.x==plan.target.x
      and state.target.y==plan.target.y) then
    return nil,nil,"outbound-natural-resource-target-changed"
  end
  local stage=rec and rec.reversal_stage_0855
  if not(tp and tp.pairs_by_priest and tp.station_reversal_depot_0852
      and valid(magos and magos.station) and valid(magos and magos.priest)
      and tp.pairs_by_station and tp.pairs_by_station[magos.station.unit_number]==magos
      and rec.status=="active" and rec.worker_station_unit==magos.station.unit_number
      and stage and stage.phase=="in-magos-depot"
      and stage.station_item==ITEM and stage.reversal_stage_index==4
      and state.stage_id==stage.id
      and state.writ_id==rec.id
      and state.magos_unit==magos.station.unit_number
      and state.magos_priest_unit==magos.priest.unit_number
      and state.original_senior_unit==stage.leaf_station_unit
      and state.original_senior_priest==stage.leaf_priest_unit
      and state.ghost_unit==rec.ghost_unit
      and type(rec.ghost_position)=="table"
      and state.ghost_position.x==rec.ghost_position.x
      and state.ghost_position.y==rec.ghost_position.y
      and not tp.pairs_by_station[stage.leaf_station_unit]) then
    return nil,nil,"outbound-writ-or-original-identity-changed"
  end
  local lease=Relocation.pending_for_record(stage)
  local survivor=tp.pairs_by_priest[stage.leaf_priest_unit]
  if not(lease and lease.status=="staged"
      and lease.rec_id==stage.id and lease.old_unit==stage.leaf_station_unit
      and lease.priest_unit==stage.leaf_priest_unit
      and lease.worker_unit==magos.station.unit_number
      and lease.reversal_ancestor_0855 and not valid(lease.old_station)
      and valid(lease.priest) and survivor and survivor.priest==lease.priest) then
    return nil,nil,"outbound-original-priest-lease-unverified"
  end
  local entry=tp.station_reversal_depot_0852[stage.id]
  if not(entry and valid(entry.inventory)
      and entry.record_id==stage.id and entry.item==ITEM
      and entry.magos_station_unit==magos.station.unit_number
      and entry.magos_priest_unit==magos.priest.unit_number
      and entry.leaf_station_unit==stage.leaf_station_unit
      and entry.leaf_priest_unit==stage.leaf_priest_unit
      and entry.force==magos.station.force
      and entry.surface==magos.station.surface) then
    return nil,nil,"outbound-protected-depot-identity-unverified"
  end
  -- The other three recovered items remain independently protected; no
  -- later ancestor may be spent merely because the Senior left its depot.
  local seen={[entry.inventory]=true}
  for i=1,3 do
    local earlier=rec[KEYS[i]]
    local held=earlier and Depot.get_staged(magos,earlier)
    if not(held and valid(held.inventory) and not seen[held.inventory]
        and count(held.inventory,earlier.station_item)==1) then
      return nil,nil,"outbound-prior-depot-custody-lost:"..i
    end
    seen[held.inventory]=true
  end
  if not ghost_for(magos,rec,ghost)
      and not (allow_missing_ghost and (not valid(ghost)
        or misplaced_owned_ghost(magos,rec,ghost))) then
    return nil,nil,"outbound-original-resource-ghost-unavailable"
  end
  return stage,entry
end
function M.service_first_pickup(magos,rec,command,ghost,restore_ghost)
  if not(valid(magos and magos.station) and valid(magos and magos.priest)
      and type(rec)=="table" and type(command)=="function") then
    return true,"outbound-root-or-movement-unavailable"
  end
  local state=rec.reversal_outbound_0895
  if not state then
    local proof,why=Audit.audit(magos,rec)
    if not(proof and proof.stage_count==4) then
      return true,"outbound-four-depot-audit-blocked:"..tostring(why)
    end
    local stage=rec.reversal_stage_0855
    state={phase="awaiting-local-pickup",writ_id=rec.id,
      stage_id=stage.id,magos_unit=magos.station.unit_number,
      magos_priest_unit=magos.priest.unit_number,
      original_senior_unit=stage.leaf_station_unit,
      original_senior_priest=stage.leaf_priest_unit,
      ghost_unit=rec.ghost_unit,
      ghost_position={x=rec.ghost_position.x,y=rec.ghost_position.y},
      target={x=rec.reversal_plan_0850.target.x,
        y=rec.reversal_plan_0850.target.y},
      started_tick=game and game.tick or 0}
    -- Never create a ghost merely because a stale record names one. First
    -- prove all four original item depots, the surviving Senior priest and
    -- the unchanged Magos writ, even when the original ghost is absent.
    -- Only the exact original ghost may be replanned. An unrelated ghost,
    -- even at the recorded site, must fail the existing identity gate.
    local replan_owned=misplaced_owned_ghost(magos,rec,ghost)
    local _,entry,reason=stage_identity(magos,rec,state,ghost,
      type(restore_ghost)=="function" and (not ghost or replan_owned))
    if not(entry and entry.status=="stored"
        and count(entry.inventory,ITEM)==1) then
      return true,reason or "outbound-source-item-unavailable"
    end
    if Cargo.has_record(rec) then
      return true,"outbound-existing-construction-cargo-unverified"
    end
    if not ghost or replan_owned then
      if type(restore_ghost)~="function" then
        return true,"outbound-original-resource-ghost-unavailable"
      end
      -- 0256 must independently prove the site is unoccupied and buildable.
      -- Rebind only to a freshly observed real entity-ghost; no station
      -- item is debited, and an ambiguous callback leaves custody intact.
      local ok,replacement,restore_reason=pcall(restore_ghost,magos,rec,
        replan_owned and ghost or nil)
      if not ok then
        -- Do not silently erase a Factorio API exception. No stock has
        -- been debited; preserve the original writ and report the blocker.
        local detail=tostring(replacement):gsub("[%c]"," "):sub(1,180)
        return true,"outbound-ghost-restoration-callback-error:"..detail
      end
      if not(valid(replacement) and replacement.name=="entity-ghost"
          and type(replacement.unit_number)=="number") then
        local detail=ok and type(restore_reason)=="string"
          and ":"..restore_reason or ""
        return true,"outbound-original-resource-ghost-unavailable"..detail
      end
      -- 0897: a physically blocked original site may require a new safe
      -- outward ghost position. Rebind the SAME writ only after the strict
      -- existing ghost_for command-radius, target-progress and identity gates
      -- accept the actual replacement entity. Never touch the real item here.
      local prior_unit=rec.ghost_unit
      local prior_position=rec.ghost_position
      local new_position={x=replacement.position.x,y=replacement.position.y}
      rec.ghost_unit=replacement.unit_number
      rec.ghost_position=new_position
      state.ghost_unit=replacement.unit_number
      state.ghost_position={x=new_position.x,y=new_position.y}
      if not ghost_for(magos,rec,replacement) then
        local cleaned=pcall(function()
          if replacement.valid then replacement.destroy() end
        end)
        rec.ghost_unit=prior_unit
        rec.ghost_position=prior_position
        state.ghost_unit=prior_unit
        state.ghost_position={x=prior_position.x,y=prior_position.y}
        if not cleaned or replacement.valid then
          return true,"outbound-restored-ghost-cleanup-uncertain"
        end
        return true,"outbound-restored-ghost-identity-invalid"
      end
      ghost=replacement
      state.restored_ghost_0896=true
      state.replaced_owned_ghost_0899=replan_owned or nil
      state.replanned_ghost_0897=dist2(prior_position,new_position)>0.01
    end
    state.audited_source_before=1
    state.audited_carrier_before=0
    rec.reversal_outbound_0895=state
  end
  local _,entry,reason=stage_identity(magos,rec,state,ghost)
  if not entry then return true,reason end
  local held_source=count(entry.inventory,ITEM)
  local cargo=Cargo.get(magos,rec)
  if cargo then
    local held=count(cargo.inventory,ITEM)
    if cargo.status=="carrying" and held==1 and held_source==0
        and (entry.status=="stored" or entry.status=="outbound") then
      -- Both engine-owned inventories are observed before changing the
      -- custody label. Safe to repeat after an interrupted callback/reload.
      entry.status="outbound"
      state.phase="senior-carried"
      state.picked_tick=state.picked_tick or (game and game.tick or 0)
      return true,"reversal-senior-real-item-carried-outward"
    end
    return true,"outbound-cargo-or-depot-count-ambiguous"
  end
  if Cargo.has_record(rec) or state.phase~="awaiting-local-pickup"
      or entry.status~="stored" or held_source~=1 then
    return true,"outbound-missing-or-ambiguous-item-custody"
  end
  if dist2(magos.priest.position,magos.station.position)>25 then
    if not(defines and defines.command and defines.distraction) then
      return true,"outbound-physical-return-command-unavailable"
    end
    command(magos.priest,{type=defines.command.go_to_location,
      destination=magos.station.position,radius=2,
      distraction=defines.distraction.none})
    return true,"outbound-magos-walking-to-physical-depot"
  end
  local picked,why=Cargo.pickup(magos,rec,entry.inventory)
  if not picked then return true,"outbound-physical-pickup-refused:"..tostring(why) end
  return M.service_first_pickup(magos,rec,command,ghost,restore_ghost)
end
return M
