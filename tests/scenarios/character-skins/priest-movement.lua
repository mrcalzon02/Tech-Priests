-- Real native go-to commands on the shipped ground priest prototypes. The old
-- bodies are fixture-only copies with the previous .08/.095 movement settings.
local Visuals=require("scripts.core.character_visuals")
local Catalog=require("shared.character_skin_catalog")
local M={}
local function check(ok,message)if not ok then error("[TP-PRIEST-MOVE] "..message)end end
function M.start()
  storage.skin_priest_movement={cases={},results={},index=0}
  local t=storage.skin_priest_movement
  for _,rank in ipairs({"junior","intermediate","senior","planetary-magos"})do
    for _,suffix in ipairs({"","-belt-immune"})do
      for _,variant in ipairs({"previous","current"})do
        t.cases[#t.cases+1]={rank=rank,immune=suffix~="",variant=variant,
          name=(variant=="previous" and "tp-skin-priest-legacy-" or "")..rank.."-tech-priest"..suffix}
      end
    end
  end
end
function M.tick(event,player,graphical)
  local t=storage.skin_priest_movement
  if not t or t.done then return end
  if not t.entity then
    t.index=t.index+1
    local case=t.cases[t.index]
    if not case then
      for index=1,#t.results,2 do
        local before,after=t.results[index],t.results[index+1]
        check(after.distance>before.distance*1.7,"ground movement no longer uses the previous crawl: "..after.rank)
      end
      t.done=true
      helpers.write_file("character-skins/priest-movement.json",helpers.table_to_json{passed=true,samples=t.results},false)
      log("[TP-PRIEST-MOVE] PASS eight normal/belt-immune prototypes, one native command per traversal; "..helpers.table_to_json(t.results))
      return
    end
    t.entity=player.surface.create_entity{name=case.name,position={-20,20},direction=defines.direction.east,force=player.force}
    check(t.entity and t.entity.valid,"native ground unit created: "..case.name)
    t.entity.orientation=.25
    Visuals.track(t.entity,Catalog.ranks[case.rank])
    t.entity.commandable.set_command{type=defines.command.go_to_location,destination={x=25,y=20},radius=.1,distraction=defines.distraction.none}
    t.started=event.tick;t.commands=1
  end
  local elapsed=event.tick-t.started
  if elapsed==30 then
    local p=t.entity.position
    t.start={x=p.x,y=p.y};t.previous=t.start;t.traveled=0;t.zero=0
  elseif elapsed>30 and elapsed<=90 then
    local p=t.entity.position
    local dx,dy=p.x-t.previous.x,p.y-t.previous.y
    local step=math.sqrt(dx*dx+dy*dy)
    t.traveled=t.traveled+step
    if step==0 then t.zero=t.zero+1 end
    t.previous={x=p.x,y=p.y}
  end
  local case=t.cases[t.index]
  if graphical and elapsed==60 and case.variant=="current" and case.rank=="junior" then
    game.take_screenshot{player=player,surface=player.surface,position=t.entity.position,
      resolution={1280,800},zoom=3,show_gui=false,daytime=0,force_render=true,
      path="character-skins/"..(case.immune and "priest-immune-walking.png" or "priest-ground-walking.png")}
  end
  if elapsed==90 then
    local dx,dy=t.entity.position.x-t.start.x,t.entity.position.y-t.start.y
    local row={rank=case.rank,immune=case.immune,variant=case.variant,movement_speed=t.entity.prototype.speed,
      ticks=60,path_distance=t.traveled,distance=math.sqrt(dx*dx+dy*dy),zero_steps=t.zero,native_commands=t.commands}
    check(row.distance>1,"positive native ground movement")
    check(row.zero_steps==0 and row.native_commands==1,"continuous native travel without command churn")
    check(row.distance>=row.movement_speed*60*.9,"native ground travel matches its declared movement speed")
    t.results[#t.results+1]=row
    t.entity.destroy();t.entity=nil
  end
end
function M.done()local t=storage.skin_priest_movement;return t and t.done end
function M.results()local t=storage.skin_priest_movement;return t and t.results end
return M
