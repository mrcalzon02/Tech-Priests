-- The CI attack screen must use physical stone-wall items, not fake damage.
local M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(type(M.test_combat_attack_wall)=="function",
  "combat physical attack target fixture missing")
local held=3
local attempts=0
local inv={
  valid=true,
  remove=function(args)
    assert(args.name=="stone-wall" and args.count==1)
    local n=math.min(held,1);held=held-n;return n
  end,
  insert=function(args)
    held=held+args.count;return args.count
  end,
}
local created={}
local surface={
  can_place_entity=function(args)
    return args.name=="stone-wall" and args.force.name=="player"
  end,
  create_entity=function(args)
    attempts=attempts+1
    local wall={name=args.name,position=args.position,force=args.force,
      valid=true,unit_number=90+attempts}
    created[#created+1]=wall
    return wall
  end,
}
local station={valid=true,name="intermediate-cogitator-station",
  position={x=64,y=0},surface=surface,force={name="player"}}
for i=1,3 do
  local wall=M.test_combat_attack_wall(station,inv,i)
  assert(wall.valid and wall.name=="stone-wall"
      and wall.position.x==86 and wall.position.y==(i-2)*4,
    "physical test wall not placed on expected forward defense")
end
assert(held==0 and #created==3,
  "physical combat targets were not paid for exactly")
local ok,err=pcall(M.test_combat_attack_wall,station,inv,1)
assert(not ok and tostring(err):find("COMBAT_PHYSICAL_WALL_NOT_OWNED",1,true)
    and held==0 and attempts==3,
  "out-of-stock test generated a free wall or hid supply failure")
print("[combat-physical-attack-wall] PASS physical wall, exact inventory debit")
