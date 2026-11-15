-- Execute the actual generated canonical selector, not a copied algorithm.
local file=assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_014.lua","r"))
local text=file:read("*a");file:close()
local body=assert(text:match("(function find_enemy_target%(station, radius, priest%).-)\n%-%- 0%.1%.674%-dev / 0786:"))
assert(load(body))()
local own={name="tp-arena-1"};local rival={name="tp-arena-2"}
local bugs={name="enemy"};local ally={name="allied-priests"};local neutral={name="neutral"}
local diplomacy={[rival]=true,[bugs]=true}
own.is_enemy=function(force)return diplomacy[force]==true end
game={forces={own=own,rival=rival,bugs=bugs,ally=ally,neutral=neutral}}
local target={valid=true,force=rival,health=100,position={x=3,y=0}}
local scans=0
local surface={find_entities_filtered=function(filters)
 scans=scans+1
 assert(type(filters.force)=="table","selector still filters by a literal enemy force")
 local selected={};for _,force in pairs(filters.force)do selected[force]=true end
 assert(not selected[own]and not selected[ally]and not selected[neutral],"friendly/neutral force admitted")
 return selected[rival]and{target}or{}
end}
local station={valid=true,force=own,surface=surface,position={x=0,y=0}}
tech_priests_0248_pair_for_station_and_priest=function()end
find_space_asteroid_targets=function()return{}end
get_entity_health_or_nil=function(e)return e.health end
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Safety=require("scripts.core.combat_safety")
tech_priests_0248_is_enemy_of_station=function(s,e)
 return s.force.is_enemy(e.force)and Safety.is_valid_hostile_target(s,e)
end
is_asteroid_threat_entity=function()return false end
score_threat_to_station_and_priest=function(e)return e.position.x^2,e.position.x^2 end
assert(find_enemy_target(station,10)==target,"hostile non-biter priest force remained invisible")
target.destructible=false
assert(find_enemy_target(station,10)==nil,"invulnerable hostile proxy monopolized canonical threat selection")
local defending={station=station,combat_target=target,target=target,mode="combat"}
assert(Safety.clear_invalid_combat_state(defending,"native-invulnerable-proxy")
 and not defending.combat_target and not defending.target,
 "persisted invulnerable proxy target could not be retired")
target.destructible=true
assert(find_enemy_target(station,10)==target,"damageable rival supply-chain target became ineligible")
diplomacy[rival]=false
assert(find_enemy_target(station,10)==nil,"changed diplomacy retained a hostile priest target")
diplomacy[bugs]=false
local before=scans
assert(find_enemy_target(station,10)==nil and scans==before,"no hostile force triggered a broad scan")
print("PASS canonical threat discovery sees hostile priest forces and respects current diplomacy")
