-- Production AAI bridge. AAI owns movement, targeting, drivers, fuel and native shooting.
-- This adapter owns only identity/presentation and validated command handoff.
local C=require("shared.combat_roster_catalog")
local Visuals=require("scripts.core.character_visuals")
local QualityAudit=require("scripts.core.combat_quality_contract")
local Registry=require("scripts.core.runtime_event_registry")
local M={handlers={}}
local replacement_handler
function M.set_replacement_handler(fn) replacement_handler=fn end
local function valid(e) return e and e.valid end
local function finite_position(pos)
 return type(pos)=="table" and type(pos.x)=="number" and type(pos.y)=="number"
  and pos.x==pos.x and pos.y==pos.y
  and pos.x<1000000 and pos.x> -1000000
  and pos.y<1000000 and pos.y> -1000000
end
function M.unit(entity)
 if not(valid(entity) and entity.type=="car" and C.for_entity_name(entity.name)) then return nil end
 return remote.call("aai-programmable-vehicles","get_unit_by_entity",entity)
end
function M.track(entity)
 if valid(entity) and entity.type=="car" then
  local u=C.for_entity_name(entity.name)
  if u then
   entity.minable_flag=true
   local rec=Visuals.track(entity,u.id)
   if rec then Visuals.update(rec) end
   return true
  end
 end
 return false
end
function M.pick_up(player,entity)
 if not(player and player.valid and valid(entity) and entity.type=="car"
   and C.for_entity_name(entity.name) and entity.force==player.force
   and player.can_reach_entity(entity)) then return false,"not-reachable-owned-unit" end
 local driver,passenger=entity.get_driver(),entity.get_passenger()
 if passenger then return false,"occupied-unit" end
 -- Never eject a human or an unrelated passenger. Only the exact roster's
 -- invisible AAI driver may be released, and only for this mining transaction.
 if driver and not(driver.object_name=="LuaEntity" and driver.type=="character"
   and not driver.player and driver.name==C.for_entity_name(entity.name).name.."-_-driver") then
  return false,"occupied-unit"
 end
 if driver then entity.set_driver(nil) end
 local ok,mined=pcall(function() return player.mine_entity(entity) end)
 if valid(entity) and driver and driver.valid then entity.set_driver(driver) end
 if not ok then error(mined) end
 return mined==true,mined and "picked-up" or "inventory-full"
end
function M.preserve_replaced_inventory(data)
 local source,dest=data.old_entity,data.new_entity
 if not(valid(source) and valid(dest)) then return end
 local before,after=C.for_entity_name(source.name),C.for_entity_name(dest.name)
 if not(before and after and before.id==after.id) then return end
 -- AAI's mode swap must preserve the exact entity quality. This read-only
 -- custody report catches lost quality or unpaid gains in the same original
 -- replacement callback without manufacturing an actor or interrupting the
 -- independently correct inventory transfer.
 if storage and storage.tech_priests then
  QualityAudit.audit_replacement(storage.tech_priests,source,dest,
   game and game.tick or 0,log)
 end
 -- AAI 0.9.2 copies get_contents() during mode replacement. That loses
 -- partial magazine/durability/entity metadata. Both native inventories are
 -- still alive at this callback; swap the original stacks into the new body.
 -- The old body receives AAI's copies and is then destroyed by AAI itself.
 -- No inventory is minted, resized, inferred or credited by this adapter.
 for _,index in ipairs({defines.inventory.car_ammo,defines.inventory.car_trunk}) do
  local a,b=source.get_inventory(index),dest.get_inventory(index)
  assert(a and b and #a==#b,"Combat AAI replacement inventory shape changed")
  local function counts(inv)
   local values={};for i=1,#inv do local s=inv[i];if s.valid_for_read then
    local k=s.name..":"..s.quality.name;values[k]=(values[k] or 0)+s.count
   end end;return values
  end
  local x,y=counts(a),counts(b)
  for k,n in pairs(x) do assert(y[k]==n,"AAI combat inventory copy mismatch") end
  for k,n in pairs(y) do assert(x[k]==n,"AAI combat inventory copy mismatch") end
  for i=1,#a do
   if a[i].valid_for_read or b[i].valid_for_read then
    assert(a[i].swap_stack(b[i]),"Combat original stack transfer refused")
   end
  end
 end
end
function M.command(entity,force,order)
 if not(valid(entity) and force and entity.force==force and type(order)=="table") then return false,"force-or-entity-invalid" end
 local unit=M.unit(entity)
 if not unit then return false,"not-managed-by-aai" end
 local data={unit_id=unit.unit_id}
 if order.stop==true then data.target_speed=0
 elseif finite_position(order.position) then
  data.target_position={x=order.position.x,y=order.position.y}
 else return false,"invalid-order" end
 -- AAI leaves an unfuelled navigator passive but retains its destination.
 -- Its same-tile command fast path then updates only coordinates, so a fresh
 -- order after real refuelling must clear that stale destination through the
 -- native stop command first. Never manufacture fuel or drive the body here.
 if not order.stop and unit.mode=="passive" and unit.target_position then
  remote.call("aai-programmable-vehicles","set_unit_command",{unit_id=unit.unit_id,target_speed=0})
 end
 remote.call("aai-programmable-vehicles","set_unit_command",data)
 return true,unit.unit_id
end
local function built(event)
 local e=event.entity
 if M.track(e) and not M.unit(e) then
  -- AAI itself omits vehicle management on robot-built events. Script/player
  -- deployment is idempotent; this callback fills only that native gap.
  remote.call("aai-programmable-vehicles","on_entity_deployed",{entity=e})
 end
end
function M.install()
 assert(Registry.on_event("tech-priests-pick-up-combat-unit",function(event)
  local player=game.get_player(event.player_index)
  if player and player.valid then return M.pick_up(player,player.selected) end
 end,nil,{owner="combat_roster_bridge",route="native-mine-control-pickup"}))
 Registry.on_configuration_changed(function()
  local names={}
  for _,u in ipairs(C.units) do
   for _,suffix in ipairs({"","-_-solid","-_-ghost"}) do names[#names+1]=u.name..suffix end
  end
  for _,surface in pairs(game.surfaces) do
   for _,entity in pairs(surface.find_entities_filtered{name=names}) do M.track(entity) end
  end
 end,{owner="combat_roster_bridge",route="restore-existing-unit-pickup"})
 assert(Registry.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
   defines.events.script_raised_built,defines.events.script_raised_revive},built,nil,
  {owner="combat_roster_bridge",route="physical-deployment",priority=600}))
 remote.add_interface("tech-priests-combat",{
  on_entity_replaced=function(data)
   M.preserve_replaced_inventory(data)
   M.track(data.new_entity)
   if replacement_handler then replacement_handler(data) end
  end,
  on_entity_deployed=function(data) M.track(data.entity) end,
  on_unit_change_mode=function(data) if data.unit then M.track(data.unit.vehicle) end end,
  command=function(data)
   local force=data.force_index and game.forces[data.force_index]
   return M.command(data.entity,force,data.order)
  end,
  request_muster=function(data) return M.handlers.request_muster(data) end,
  command_from_priest=function(data) return M.handlers.command_from_priest(data) end,
 })
 return true
end
return M
