-- Exercise the real legacy perimeter executor, not a mocked replacement.
local stock={["gun-turret"]=0,["firearm-magazine"]=60}
local function inventory()
  return {valid=true,
    get_contents=function()
      local contents={}
      for item,count in pairs(stock) do
        if count>0 then
          contents[#contents+1]={name=item,count=count,quality="normal"}
        end
      end
      return contents
    end,
    get_item_count=function(name)return stock[name] or 0 end,
    remove=function(args)
      local count=math.min(stock[args.name] or 0,args.count)
      stock[args.name]=(stock[args.name] or 0)-count
      return count
    end,
    insert=function(args)
      stock[args.name]=(stock[args.name] or 0)+args.count
      return args.count
    end,
  }
end
local chest=inventory()
game={tick=100}
defines={inventory={chest=1,turret_ammo=2},
  direction={north=0,east=2},
  command={go_to_location=1},
  distraction={by_enemy=1}}
local proto={type="ammo-turret",attack_parameters={range=18}}
tech_priests_get_entity_prototype_name_from_item_0184=function(name)
  if name=="gun-turret" then return "gun-turret" end
end
tech_priests_get_entity_prototype_0440=function(name)
  if name=="gun-turret" then return proto end
end
tech_priests_get_item_prototype_0440=function(name)
  if name=="firearm-magazine" then return {type="ammo"} end
end
tech_priests_prototype_table_0440=function(kind)
  if kind=="item" then
    return {["gun-turret"]={place_result={name="gun-turret"}},
      ["firearm-magazine"]={type="ammo"}}
  end
  return {}
end
TechPriestsPlanningConstraints0646={
  entity_unlocked=function()return false,"recipe-locked" end,
  item_for_entity=function(name)
    if name=="gun-turret" then return "gun-turret" end
    return nil
  end,
  defense_position_allowed=function()return true end
}
local turret_ammo=0
local turret_inventory={valid=true,
  insert=function(stack)turret_ammo=turret_ammo+stack.count;return stack.count end,
  get_item_count=function(name)if name=="firearm-magazine" then return turret_ammo end;return 0 end,
}
local constructed={}
local surface={
  can_place_entity=function()return true end,
  find_entities_filtered=function()return {} end,
  create_entity=function(arg)
    local e={valid=true,name=arg.name,type="ammo-turret",
      position=arg.position,force=arg.force,unit_number=100+#constructed,
      get_inventory=function(id)
        if id==defines.inventory.turret_ammo then return turret_inventory end
      end}
    constructed[#constructed+1]=e
    return e
  end,
}
local force={valid=true,name="player"}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=11,force=force,surface=surface,position={x=0,y=0},
  get_inventory=function(id)
    if id==defines.inventory.chest then return chest end
  end}
local priest={valid=true,unit_number=12,position={x=20,y=0},force=force}
local pair={station=station,priest=priest,radius=20,
  defense_perimeter_0259={threats={{
    position={x=20,y=0},tick=game.tick,reason="hostile-damage"}},
    last_hostile_damage_0816={tick=game.tick}}}
storage={tech_priests={pairs_by_station={[11]=pair}}}
tick_pair=function()return false end
dofile("tech-priests_src/scripts/defense_perimeter.lua")
assert(type(tick_pair)=="function","defense perimeter dispatcher unavailable")
local defense_bridge=rawget(_G,"TechPriestsDefensePerimeter0259")
assert(defense_bridge and type(defense_bridge.service_pair)=="function"
  and type(defense_bridge.has_pending)=="function",
  "canonical dispatcher defense service was not exported")
-- No actual turret item: an incident must remain queued, not invent a gun.
tick_pair(pair)
assert(not pair.defense_task_0259
  and #pair.defense_perimeter_0259.threats==1
  and stock["gun-turret"]==0,
  "locked turret or missing item improperly satisfied physical defense")
-- Physical inventory exists even though the research recipe is still locked.
-- Factorio permits placement of an already-manufactured item.
stock["gun-turret"]=1
game.tick=game.tick+180
pair.machine_logistics_custody_0528=true
local yield=defense_bridge.service_pair(pair)
assert(yield.waiting==1 and not pair.defense_task_0259
  and stock["gun-turret"]==1
  and #pair.defense_perimeter_0259.threats==1,
  "canonical defense bridge stole a reserved machine item")
pair.machine_logistics_custody_0528=nil
local started=defense_bridge.service_pair(pair)
assert(started.acted==1 and pair.defense_task_0259
  and pair.defense_task_0259.type=="build-turret"
  and pair.defense_task_0259.item=="gun-turret"
  and #pair.defense_perimeter_0259.threats==0,
  "canonical dispatcher did not start a physically stocked turret")
game.tick=game.tick+1
local walking=defense_bridge.service_pair(pair)
assert(walking.acted==1,"canonical service did not advance turret task")
game.tick=game.tick+61
local built=defense_bridge.service_pair(pair)
assert(built.acted==1 and #constructed==1
  and stock["gun-turret"]==0
  and pair.defense_perimeter_0259.turrets_built==1,
  "canonical turret construction failed physical item accounting")
assert(pair.defense_task_0259
  and pair.defense_task_0259.type=="ammo-turret",
  "real new turret did not schedule ammunition service")
game.tick=game.tick+1
local armed=defense_bridge.service_pair(pair)
assert(armed.acted==1 and turret_ammo==20
  and stock["firearm-magazine"]==40,
  "canonical ammunition service lost physical custody")
-- Factorio forbids require() once simulation begins. The real perimeter
-- executor and legacy tick wrapper must reuse an initialization-time module.
local memory_calls=0
_G.TechPriestsCombatDefenseReaction0816={
  reconcile_pair=function(owner,find_turrets)
    assert(owner==pair and type(find_turrets)=="function",
      "incident memory lost physical perimeter lookup ownership")
    memory_calls=memory_calls+1
    return 0
  end,
}
pair.defense_perimeter_0259.hostile_incidents_0817={{id=19}}
local initial_require=require
require=function() error("Require can't be used outside of control.lua parsing.") end
game.tick=game.tick+90
local okay,bridge_result=pcall(defense_bridge.service_pair,pair)
pair.defense_perimeter_0259.last_dispatcher_service_tick_0818=nil
local legacy_ok=pcall(tick_pair,pair)
require=initial_require
_G.TechPriestsCombatDefenseReaction0816=nil
assert(okay and legacy_ok and memory_calls>=2,
  "Factorio runtime perimeter invoked forbidden require instead of preloaded incident memory")
pair.defense_perimeter_0259.hostile_incidents_0817=nil
print("[defense-prestock-reaction] PASS incident preserved, physical turret built, armed")
-- The same source-validation step also exercises the canonical dispatch bridge.
dofile("tests/unit/defense_canonical_dispatcher.lua")
