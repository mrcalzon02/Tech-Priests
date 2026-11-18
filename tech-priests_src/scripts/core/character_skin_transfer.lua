-- One-time vanilla/custom presentation-host transfer. Ordinary skin selections
-- reuse the same host and never touch inventories or the character controller.
local M={host_name="tech-priests-custom-character"}
local transferring={}
function M.in_progress(index) return transferring[index]==true end
local modifiers={
  "character_crafting_speed_modifier","character_mining_speed_modifier","character_running_speed_modifier",
  "character_build_distance_bonus","character_item_drop_distance_bonus","character_reach_distance_bonus",
  "character_resource_reach_distance_bonus","character_item_pickup_distance_bonus","character_loot_pickup_distance_bonus",
  "character_inventory_slots_bonus","character_trash_slot_count_bonus","character_maximum_following_robot_count_bonus",
  "character_health_bonus"}
local function valid(entity) return entity and entity.valid end
local function read(object,key)
  local ok,value=pcall(function() return object[key] end)
  return ok and value or nil
end
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for k,v in pairs(a) do if not same(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function copy_logistics(old,new)
  local source=old.get_logistic_sections()
  if not source then return end
  local target=assert(new.get_logistic_sections(),"Missing destination logistic sections")
  for i=target.sections_count,1,-1 do
    local section=target.get_section(i)
    if section and section.is_manual then assert(target.remove_section(i),"Cannot clear destination request section") end
  end
  for _,section in ipairs(source.sections) do
    if section.is_manual then
      local created=assert(target.add_section(section.group),"Cannot copy logistic request section")
      if section.group=="" then created.filters=table.deepcopy(section.filters) end
      created.active=section.active
      created.multiplier=section.multiplier
      assert(same(created.filters,section.filters),"Logistic request filters did not survive transfer")
    end
  end
  local from,to=old.get_requester_point(),new.get_requester_point()
  if from and to then
    for _,key in ipairs({"enabled","trash_not_requested"}) do
      local value=read(from,key)
      if value~=nil then to[key]=value end
    end
  end
end
function M.block_reason(player)
  if not (player and player.valid) then return "no-character" end
  if player.controller_type~=defines.controllers.character then return "controller" end
  local old=player.character
  if not valid(old) then return "no-character" end
  if old.name~="character" and old.name~=M.host_name then return "other-character" end
  if player.driving then return "vehicle" end
  if (player.crafting_queue_size or 0)>0 then return "crafting" end
  if read(old,"character_is_in_combat") then return "combat" end
  if #(read(old,"stickers") or {})>0 then return "combat" end
  local cell=read(old,"logistic_cell")
  local network=cell and cell.valid and cell.logistic_network
  if network and network.valid and #(network.construction_robots or {})>0 then return "robots" end
  return nil
end
function M.switch(player,name)
  if transferring[player.index] then return false,"busy" end
  if valid(player.character) and player.character.name==name then return true end
  local reason=M.block_reason(player)
  if reason then return false,reason end
  local old=player.character
  local new=old.surface.create_entity{name=name,position=old.position,force=old.force,
    direction=old.direction,quality=old.quality,raise_built=false}
  if not valid(new) then return false,"placement" end
  transferring[player.index]=true
  local moved={}
  local followers={}
  local cursor_inventory=nil
  local assigned=false
  local health=old.health
  local original_bonus=old.character_inventory_slots_bonus
  local ok,err=pcall(function()
    for _,key in ipairs(modifiers) do
      local value=read(old,key)
      if value~=nil then new[key]=value end
    end
    local removed=new.copy_settings(old)
    assert(not removed or #removed==0,"Unexpected removed items while copying character settings")
    copy_logistics(old,new)
    local main=old.get_inventory(defines.inventory.character_main)
    -- Main/guns/ammo/trash move BEFORE armour. Extra temporary capacity prevents
    -- armour inventory bonuses from spilling stacks during either transaction.
    new.character_inventory_slots_bonus=original_bonus+#main
    for _,kind in ipairs({defines.inventory.character_main,defines.inventory.character_guns,
                           defines.inventory.character_ammo,defines.inventory.character_trash,
                           defines.inventory.character_armor}) do
      local source=old.get_inventory(kind)
      local target=new.get_inventory(kind)
      if source and source.valid then
        assert(target and target.valid and #target>=#source,"Destination inventory capacity mismatch")
        for slot=1,#source do
          if source.supports_filters() then target.set_filter(slot,source.get_filter(slot)) end
          if source[slot].valid_for_read then
            assert(not target[slot].valid_for_read,"Destination slot is not empty")
            assert(target[slot].swap_stack(source[slot]),"Exact item-stack transfer rejected")
            moved[#moved+1]={source=source,slot=slot,target=target}
          end
        end
        if source.supports_bar() then target.set_bar(source.get_bar()) end
      end
    end
    new.character_inventory_slots_bonus=original_bonus
    for _,key in ipairs({"selected_gun_index","tick_of_last_attack","tick_of_last_damage","destructible","operable"}) do
      local value=read(old,key)
      if value~=nil then new[key]=value end
    end
    new.health=health
    new.color=player.color
    for _,robot in pairs(player.following_robots or {}) do
      if valid(robot) then followers[#followers+1]=robot;robot.combat_robot_owner=new end
    end
    if player.cursor_stack.valid_for_read then
      cursor_inventory=game.create_inventory(1)
      assert(cursor_inventory[1].swap_stack(player.cursor_stack),"Cannot preserve cursor item")
    end
    player.character=new
    assigned=true
    if cursor_inventory then assert(player.cursor_stack.swap_stack(cursor_inventory[1]),"Cannot restore cursor item") end
    assert(old.destroy(),"Old empty character could not be retired")
  end)
  if not ok then
    -- All real stacks remain owned by one of the two characters until commit.
    -- Roll back in reverse order, restoring armour before shrinking inventories.
    if valid(old) then
      if assigned then player.character=old end
      for i=#moved,1,-1 do
        local item=moved[i]
        assert(item.source[item.slot].swap_stack(item.target[item.slot]),"Skin transfer rollback rejected")
      end
      for _,robot in ipairs(followers) do if valid(robot) then robot.combat_robot_owner=old end end
      if cursor_inventory and cursor_inventory[1].valid_for_read then
        assert(player.cursor_stack.swap_stack(cursor_inventory[1]),"Cursor rollback rejected")
      end
      if valid(new) then new.destroy() end
    end
    if cursor_inventory and cursor_inventory.valid then cursor_inventory.destroy() end
    if log then log("[Tech-Priests character skins] transfer rolled back: "..tostring(err)) end
    transferring[player.index]=nil
    return false,"transfer"
  end
  if cursor_inventory and cursor_inventory.valid then cursor_inventory.destroy() end
  transferring[player.index]=nil
  return true
end
return M
