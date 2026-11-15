-- Read-only intelligence from the existing research-finished event owner.
-- No polling, research grants, world mutation, or saved notification backlog.
local Registry=require("scripts.core.runtime_event_registry")
local Options=require("scripts.core.enemy_colony_options")
local M={}
local milestones={automation=true,["automation-2"]=true,["automation-3"]=true,
 ["rocket-silo"]=true,rocketry=true,artillery=true,spidertron=true,
 ["nuclear-power"]=true,["fusion-reactor"]=true,["laser-turret"]=true,
 ["railgun"]=true,["atomic-bomb"]=true,["space-platform"]=true,
 ["space-platform-thruster"]=true,["electromagnetic-plant"]=true,
 ["foundry"]=true,["cryogenic-plant"]=true,["captive-biter-spawner"]=true}
function M.is_milestone(name)
 return milestones[name]==true or name:find("^planet%-discovery%-")~=nil
   or name:find("science%-pack$")~=nil
end
function M.message(event)
 local research=event and event.research
 if not (research and research.valid and research.force and research.force.valid)
     or event.by_script==true or not Options.is_enemy_force(research.force)then return nil end
 local mode=Options.get("research-announcements","all")
 if mode=="off"or(mode=="milestones"and not M.is_milestone(research.name))then return nil end
 local planet=research.force.name:gsub("^tech%-priests%-renegades%-","")
 planet=planet:gsub("%-"," "):gsub("^%l",string.upper)
 local faction={"enemy-research-announcement.faction",planet}
 -- Stable variation without consuming the world's gameplay random stream.
 local hash=research.force.index
 for i=1,#research.name do hash=(hash*31+research.name:byte(i))%2147483647 end
 return {"enemy-research-announcement.intercept-"..(hash%8+1),faction,
   {"", "[technology="..research.name.."] ",research.localised_name}}
end
function M.notify(event,recipients)
 local message=M.message(event)
 if not message then return 0 end
 local sent=0
 for _,player in pairs(recipients or game.connected_players)do
  local force=player.force
  if player.valid and force and force~=event.research.force
      and not force.get_friend(event.research.force)
      and not force.get_cease_fire(event.research.force)then
   player.print(message,{color={r=1,g=0.65,b=0.3}})
   sent=sent+1
  end
 end
 return sent
end
function M.install()
 return Registry.on_event(defines.events.on_research_finished,M.notify,nil,
   {owner="enemy_research_announcements",route="completed-research",category="chat"})~=nil
end
return M
