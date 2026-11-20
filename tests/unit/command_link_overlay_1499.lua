-- Renderer integration regression: no guessed lines in the live 0474 overlay.
-- Source mock only, never a substitute for a real Factorio visual capture.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path

local surface, force = {index=1}, {name="player-force"}
local function create_pair(unit,rank,x)
  local station = {valid=true,unit_number=unit,
    name="senior-cogitator-station",surface=surface,force=force,
    position={x=x,y=0}}
  local priest = {valid=true,unit_number=unit+1000,
    name="senior-tech-priest",surface=surface,force=force,
    position={x=x+3,y=0}}
  return {station=station,priest=priest,station_unit=unit,rank=rank,
    command_hierarchy_0480={rank=rank,superior_unit=nil,
      direct_subordinate_units={},peer_units={}}}
end

local magos=create_pair(10,4,0)
local senior=create_pair(11,3,25)
local junior_a=create_pair(12,1,45)
local junior_b=create_pair(13,1,54)
magos.station.name="planetary-magos-cogitator-station"
magos.priest.name="planetary-magos-tech-priest"
junior_a.station.name="junior-cogitator-station"
junior_b.station.name="junior-cogitator-station"

storage={tech_priests={
  pairs_by_station={[10]=magos,[11]=senior,[12]=junior_a,[13]=junior_b},
  command_hierarchy_0480={enabled=true},
}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  _installed=true,max_link_distance=220,
}
game={tick=1}
local rendered={}
local function object()
  return {valid=true,destroy=function() end}
end
rendering={
  draw_line=function(spec)
    rendered[#rendered+1]=spec
    return object()
  end,
  draw_circle=function(spec) return object() end,
}
local player={valid=true,index=1,name="unit-tester",selected=magos.station,
  surface=surface,force=force,game_view_settings={show_entity_info=false}}
local M=require("scripts.core.alt_writ_visual_stability_0474")

-- Pair link is expected, but geometric closeness cannot create network lines.
assert(M.refresh_player(player)==true)
local root=storage.tech_priests.alt_writ_visual_stability_0474
assert(root.stats.last_lines==0 and root.stats.last_circles==4)
local function network_segments()
  local count=0
  for _,spec in ipairs(rendered) do
    if spec.from and spec.from.x and spec.to and spec.to.x then count=count+1 end
  end
  return count
end
assert(network_segments()==0,"nearest-rank guess created a fake gray network line")

-- Only two verified relationships become visible after actual 0480 slates.
magos.command_hierarchy_0480.direct_subordinate_units={11}
senior.command_hierarchy_0480.superior_unit=10
junior_a.command_hierarchy_0480.peer_units={13}
junior_b.command_hierarchy_0480.peer_units={12}
rendered={}
game.tick=61
assert(M.refresh_player(player)==true)
assert(root.stats.last_lines==2 and root.stats.last_direct_links==1
  and root.stats.last_peer_links==1,"command-ledger overlay counters wrong")
assert(network_segments()>=2,"verified command lines were not drawn")
local description=M.describe()
assert(description:find("verified%-direct=1") and
  description:find("mutual%-junior%-peers=1"),"no truthful command diagnostics")

-- If command authority is disabled, a stale slate must NOT be drawn.
storage.tech_priests.command_hierarchy_0480.enabled=false
rendered={}
game.tick=122
assert(M.refresh_player(player)==true)
assert(root.stats.last_lines==0 and root.stats.last_direct_links==0
  and root.stats.last_peer_links==0,"disabled hierarchy leaked visible links")
assert(network_segments()==0)

print("[command-link-overlay-1499] PASS no geometric guesses, verified-only links")
