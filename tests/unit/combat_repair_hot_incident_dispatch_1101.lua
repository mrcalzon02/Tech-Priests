-- 1101: production 0488 must deliver the previously identified 0517
-- tactical candidate under a genuine hot 0817 incident after live biters
-- disappear, without preempting another physical item's custody.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Arbiter=require("scripts.core.action_state_arbiter_0488")
game={tick=110400}
local force={name="player",index=1}
local enemy={name="enemy",index=2}
local surface={index=1}
local station={valid=true,unit_number=31,force=force,surface=surface,
  position={x=0,y=0},name="intermediate-cogitator-station"}
local priest={valid=true,unit_number=32,force=force,surface=surface,
  position={x=0,y=0}}
local wall={valid=true,name="stone-wall",unit_number=41,force=force,
  surface=surface,position={x=16,y=0},health=150,max_health=350}
local pair={station=station,priest=priest,mode="idle",
  order_queue_0469={current={kind="logistics",status="active"}},
  defense_perimeter_0259={hostile_incidents_0817={{
    id=1,station_unit=31,force_name="player",surface_index=1,
    position={x=16,y=0},last_tick=110100,active_until=111000,
    hit_count=2}}}}
local calls=0
_G.TechPriestsCombatRepairDoctrine0517={
  recommend_action=function(p)
    assert(p==pair)
    calls=calls+1
    return {kind="combat-repair",target=wall,item="repair-pack"}
  end}
local function expect(kind,why)
  local a=Arbiter.action(pair)
  assert(a.kind==kind,why..": "..tostring(a.kind))
  return a
end
local selected=expect("combat-repair",
  "routine logistics permanently starved real hot-wall repair")
assert(selected.target==wall and calls==1,
  "combat repair did not preserve same physical target")
pair.order_queue_0469.current={kind="item-family-logistics",status="active"}
expect("combat-repair","routine item-family logistics starved real wall repair")
pair.order_queue_0469.current={kind="machine-logistics",status="active"}
expect("combat-repair","routine machine logistics starved real wall repair")
pair.order_queue_0469.current={kind="logistics",status="active"}
pair.direct_acquisition_custody_0513={item_name="iron-ore",count=1}
expect("acquisition","physical direct-acquisition cargo was preempted")
pair.direct_acquisition_custody_0513=nil
pair.construction_task_0338={phase="move-site",
  carried={item_name="medium-electric-pole",count=1}}
expect("acquisition","physically carried frontier pole was preempted")
pair.construction_task_0338=nil
pair.item_family_custody_0702={item_name="coal",count=1}
expect("acquisition","physical item-family cargo was preempted")
pair.item_family_custody_0702=nil
local incident=pair.defense_perimeter_0259.hostile_incidents_0817[1]
incident.force_name=enemy.name
expect("acquisition","another force's incident triggered wall repair")
incident.force_name=force.name
incident.surface_index=2
expect("acquisition","foreign-surface incident triggered wall repair")
incident.surface_index=surface.index
incident.station_unit=999
expect("acquisition","foreign station's incident triggered wall repair")
incident.station_unit=station.unit_number
incident.active_until=game.tick
expect("acquisition","cooled incident triggered wall repair")
incident.active_until=game.tick+500
pair.order_queue_0469.current={kind="combat",status="active"}
expect("combat","hostile combat order was overridden by repair")
print("[combat-repair-hot-incident-dispatch-1101] PASS 0817 hot damage breaks routine logistics starvation without stealing held item custody")
