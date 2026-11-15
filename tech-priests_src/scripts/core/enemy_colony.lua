-- Initial world generation only. All subsequent work belongs to normal priests.
local M={}
local Options=require("scripts.core.enemy_colony_options")
local function amount(value)
 return math.max(1,math.floor(value*Options.get("starter-stock-multiplier",1)))
end
local layout={
 {"planetary-magos-cogitator-station",0,0},
 {"senior-cogitator-station",-4,0},{"intermediate-cogitator-station",4,0},
 {"steel-chest",-3,4},{"steel-chest",3,4},
 {"assembling-machine-1",-4,8},{"assembling-machine-1",0,8},
 {"lab",5,8},{"stone-furnace",-8,5},{"stone-furnace",-8,8},
 {"gun-turret",-9,-7},{"gun-turret",9,-7},
 {"solar-panel",-5,-5},{"solar-panel",0,-5},{"solar-panel",5,-5},
 {"accumulator",-2,-9},{"accumulator",2,-9},
 {"medium-electric-pole",-5,4},{"medium-electric-pole",1,4},
 {"medium-electric-pole",5,4},
 {"medium-electric-pole",5,-2},{"medium-electric-pole",-3,-2},
}
local patches={{"iron-ore",-10,-1},{"copper-ore",10,-1},
 {"coal",-10,11},{"stone",10,11}}
local stock={{"iron-plate",300},{"copper-plate",200},{"coal",200},{"stone",100},
 {"iron-gear-wheel",80},{"electronic-circuit",80},{"copper-cable",100},
 {"transport-belt",80},{"inserter",20},{"small-electric-pole",20},
 {"pipe",40},{"repair-pack",30},{"firearm-magazine",100},
 {"assembling-machine-1",3},{"stone-furnace",4},{"burner-mining-drill",4},
 {"lab",1},{"boiler",1},{"steam-engine",2},{"offshore-pump",1},
 {"senior-cogitator-station",1},{"intermediate-cogitator-station",1},
 {"junior-cogitator-station",2}}
local function position(center,x,y)return{x=center.x+x,y=center.y+y}end
function M.can_place(surface,center)
  for _,entry in ipairs(layout)do
    if not surface.can_place_entity{name=entry[1],position=position(center,entry[2],entry[3])}then
      return false
    end
  end
  for _,patch in ipairs(patches)do for x=-1,1 do for y=-1,1 do
    if not surface.can_place_entity{name=patch[1],
      position=position(center,patch[2]+x,patch[3]+y)}then return false end
  end end end
  return true
end
local function colony_force(planet)
  local name="tech-priests-renegades-"..planet
  local force=game.forces[name]
  if force then return force end
  force=game.create_force(name)
  force.ai_controllable=false
  enable_tech_priest_emergency_micro_industry_for_force(force)
  -- Established settlements already know the three introductory trigger rites
  -- needed for their seeded lab/electronics. Subsequent research is paid normally.
  for _,name in ipairs{"steam-power","electronics","automation-science-pack"}do
    if force.technologies[name]then force.technologies[name].researched=true end
  end
  -- Finite initial objective, analogous to the player's first research order.
  -- This queues a native technology; real labs, science and energy pay its cost.
  if force.technologies.automation and not force.current_research then
    assert(force.add_research("automation"),"Colony initial research order refused")
  end
  for _,other in pairs(game.forces)do if other~=force then
    local allied=other.name=="enemy" or other.name=="neutral"
      or other.name:find("^tech%-priests%-renegades%-")~=nil
    force.set_friend(other,allied);other.set_friend(force,allied)
    force.set_cease_fire(other,allied);other.set_cease_fire(force,allied)
  end end
  return force
end
function M.create(surface,center,planet)
  if not M.can_place(surface,center)then return nil end
  if not Options.admit_colony(surface,planet)then return nil end
  local force=colony_force(planet)
  local colony={force=force.name,position=center,stations={},entities={}}
  -- Stage and stock physical entities before notifying normal station ownership.
  for _,entry in ipairs(layout)do
    local entity=surface.create_entity{name=entry[1],force=force,
      position=position(center,entry[2],entry[3]),raise_built=false}
    assert(entity and entity.valid,"Colony placement failed: "..entry[1])
    colony.entities[#colony.entities+1]=entity
    if entry[1]:find("cogitator%-station$")then
      colony.stations[#colony.stations+1]=entity
    elseif entry[1]=="gun-turret"then entity.insert{name="firearm-magazine",count=amount(30)}
    elseif entry[1]=="stone-furnace"then entity.insert{name="coal",count=amount(20)}
    elseif entry[1]=="assembling-machine-1"then
      entity.set_recipe(entry[2]==-4 and "iron-gear-wheel" or "copper-cable")
      entity.insert{name=entry[2]==-4 and "iron-plate" or "copper-plate",count=amount(20)}
    elseif entry[1]=="lab"then entity.insert{name="automation-science-pack",count=amount(20)}
    end
  end
  local chests={colony.entities[4],colony.entities[5]}
  for i,entry in ipairs(stock)do
    local wanted=amount(entry[2])
    assert(chests[(i-1)%2+1].insert{name=entry[1],count=wanted}==wanted,
      "Colony starter stock capacity exceeded")
  end
  for _,patch in ipairs(patches)do for x=-1,1 do for y=-1,1 do
    assert(surface.create_entity{name=patch[1],amount=Options.get("ore-per-tile",1500),
      position=position(center,patch[2]+x,patch[3]+y)},"Colony ore placement failed")
  end end end
  for _,station in ipairs(colony.stations)do
    script.raise_script_built{entity=station}
    -- Self-raised events are not a synchronous local lifecycle call.
    -- Invoke the existing canonical build owner, never manufacture a pair.
    if not storage.tech_priests.pairs_by_station[station.unit_number]then
      on_built{entity=station,created_entity=station}
    end
    local pair=storage.tech_priests.pairs_by_station[station.unit_number]
    assert(pair and pair.priest and pair.priest.valid,"Colony normal priest binding failed")
    pair.emergency_operation_auto_allowed_0190=true
    pair.logistic_frustration_due_tick=game.tick
    assert(tech_priests_set_emergency_operation_0184(pair,true,"planetary-colony"),
      "Colony independent operation authorization failed")
  end
  return colony
end
return M
