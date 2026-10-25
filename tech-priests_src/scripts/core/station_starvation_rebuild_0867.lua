-- Method I 0867: read-only prerequisite for outward station reconstruction.
-- Four counted, DISTINCT physical 0852 inventories and all original living
-- priests are mandatory. This is not an item debit or build authorization.
local Depot=require("scripts.core.station_starvation_depot_0852")
local M={version="0.1.674-dev.0867"}
local items={
  "junior-cogitator-station","junior-cogitator-station",
  "intermediate-cogitator-station","senior-cogitator-station"
}
local stages={
  "reversal_stage_0851","reversal_stage_0853",
  "reversal_stage_0854","reversal_stage_0855"
}
local function valid(entity) return entity and entity.valid end
function M.audit(magos,rec)
  local tp=storage and storage.tech_priests
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(magos and magos.station) and valid(magos and magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and type(rec)=="table" and rec.status=="active"
      and rec.worker_station_unit==magos.station.unit_number) then
    return nil,"four-depot-root-or-live-writ-unavailable"
  end
  local plan=rec.reversal_plan_0850
  if not(type(plan)=="table" and plan.status=="leaf-first-preflight-only"
      and type(plan.stages)=="table" and #plan.stages==4
      and plan.root_station_unit==magos.station.unit_number
      and plan.required_item=="senior-cogitator-station") then
    return nil,"four-depot-reversal-plan-invalid"
  end
  -- A saved four-item receipt is not permission to reconstruct toward a
  -- different target. The live Magos mission must still name the same ore.
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(type(plan.target)=="table" and type(plan.target.x)=="number"
      and type(plan.target.y)=="number" and mission
      and type(mission.target)=="table"
      and mission.target.x==plan.target.x
      and mission.target.y==plan.target.y) then
    return nil,"four-depot-original-resource-target-changed"
  end
  local seen_units,seen_priests,seen_inventories={},{},{}
  local proof={root_station_unit=magos.station.unit_number,
    root_priest_unit=magos.priest.unit_number,
    stage_count=4,items={}}
  for i=1,4 do
    local step=plan.stages[i]
    local stage=rec[stages[i]]
    local item=items[i]
    local expected_id=i==1
      and ("reversal-leaf:"..tostring(rec.id)..":"..
        tostring(type(step)=="table" and step.station_unit))
      or ("reversal-ancestor:"..tostring(rec.id)..":"..i..":"..
        tostring(type(step)=="table" and step.station_unit))
    if not(type(step)=="table" and type(stage)=="table"
        and stage.phase=="in-magos-depot" and stage.id==expected_id
        and step.item==item and stage.station_item==item
        and step.station_unit==stage.leaf_station_unit
        and step.parent_station_unit==stage.worker_station_unit
        and type(step.station_unit)=="number"
        and type(step.parent_station_unit)=="number"
        and type(stage.leaf_priest_unit)=="number"
        and type(stage.worker_priest_unit)=="number"
        and (i==1 or stage.reversal_stage_index==i)
        and (i~=1 or stage.reversal_stage_index==nil)
        and not seen_units[step.station_unit]
        and not seen_priests[stage.leaf_priest_unit]
        and not tp.pairs_by_station[step.station_unit]) then
      return nil,"four-depot-stage-identity-or-removal-invalid:"..i
    end
    -- These four receipts must describe the SAME physical five-station
    -- hierarchy, not four independently plausible but cross-wired leases.
    -- The carrier of each child is the next recovered original priest;
    -- the final carrier is the surviving Magos himself.
    local parent=i==4 and magos.station.unit_number
      or (type(plan.stages[i+1])=="table"
        and plan.stages[i+1].station_unit)
    local worker_priest=i==4 and magos.priest.unit_number
      or (type(rec[stages[i+1]])=="table"
        and rec[stages[i+1]].leaf_priest_unit)
    if not(parent and step.parent_station_unit==parent
        and stage.worker_station_unit==parent
        and worker_priest and stage.worker_priest_unit==worker_priest
        and stage.worker_priest_unit~=stage.leaf_priest_unit
        and stage.leaf_priest_unit~=magos.priest.unit_number) then
      return nil,"four-depot-original-chain-or-carrier-invalid:"..i
    end
    local priest_pair=tp.pairs_by_priest[stage.leaf_priest_unit]
    if not(priest_pair and valid(priest_pair.priest)
        and priest_pair.priest.unit_number==stage.leaf_priest_unit) then
      return nil,"four-depot-original-priest-unavailable:"..i
    end
    local entry,why=Depot.get_staged(magos,stage)
    if not(entry and valid(entry.inventory)
        and not seen_inventories[entry.inventory]) then
      return nil,"four-depot-item-or-separate-inventory-unverified:"..
        i..":"..tostring(why)
    end
    seen_units[step.station_unit]=true
    seen_priests[stage.leaf_priest_unit]=true
    seen_inventories[entry.inventory]=true
    proof.items[i]={
      stage_index=i,station_unit=stage.leaf_station_unit,
      original_priest_unit=stage.leaf_priest_unit,
      worker_station_unit=stage.worker_station_unit,
      item=item,record_id=stage.id,count=1
    }
  end
  -- An audit certifies observed custody only at the instant it is called.
  -- Never persist this snapshot as a future entitlement to spend cargo.
  return proof,"four-real-depots-and-original-priests-verified"
end
return M
