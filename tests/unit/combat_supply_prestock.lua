-- CI harness physical pre-stocking: inventory conservation and defense custody.
local log_records={}
log=function(message) log_records[#log_records+1]=message end
prototypes={item={}}
for _,name in ipairs({"gun-turret","firearm-magazine","stone-wall",
    "repair-pack","iron-plate","coal","stone","copper-ore"}) do
  prototypes.item[name]={}
end
defines={inventory={chest=1}}
local function inventory(capacity,initial)
  local stock={}
  for name,count in pairs(initial or {}) do stock[name]=count end
  local object={valid=true}
  local function slots()
    local n=0
    for _,count in pairs(stock) do if count>0 then n=n+1 end end
    return n
  end
  object.get_item_count=function(name)return stock[name] or 0 end
  object.get_contents=function()
    local out={}
    for name,count in pairs(stock) do
      if count>0 then out[#out+1]={name=name,count=count,quality="normal"} end
    end
    return out
  end
  object.insert=function(stack)
    if stack.count<=0 then return 0 end
    if (stock[stack.name] or 0)<=0 and slots()>=capacity then return 0 end
    stock[stack.name]=(stock[stack.name] or 0)+stack.count
    return stack.count
  end
  object.remove=function(stack)
    local n=math.min(stock[stack.name] or 0,stack.count)
    stock[stack.name]=(stock[stack.name] or 0)-n
    return n
  end
  return object
end
local M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(type(M.test_prestock_defense)=="function","physical supply service absent")
local depot=nil
local surface={
  can_place_entity=function()return true end,
  create_entity=function(args)
    local chest=inventory(48)
    depot={valid=true,name=args.name,unit_number=100,position=args.position,
      get_inventory=function()return chest end}
    return depot
  end,
}
local station={
  name="intermediate-cogitator-station",position={x=64,y=0},
  force={name="player"},surface=surface
}
local supply={{"gun-turret",5},{"firearm-magazine",160},
  {"stone-wall",70},{"repair-pack",36},
  {"iron-plate",80},{"coal",40}}
-- Four physical station slots already occupied by existing stock.
local chest=inventory(4,{
  ["gun-turret"]=2,["firearm-magazine"]=160,
  ["stone"]=30,["copper-ore"]=12})
local original={}
for _,name in ipairs({"gun-turret","firearm-magazine","stone","copper-ore"}) do
  original[name]=chest.get_item_count(name)
end
M.test_prestock_defense(station,chest,supply)
assert(depot and depot.valid,"real overflow chest not placed")
local overflow=depot.get_inventory(defines.inventory.chest)
for _,order in ipairs(supply) do
  local item,target=order[1],order[2]
  local physical=chest.get_item_count(item)+overflow.get_item_count(item)
  assert(physical==math.max(original[item] or 0,target),
    "missing, duplicated or uncounted physical stock: "..item)
end
assert(overflow.get_item_count("stone")==30
    and overflow.get_item_count("copper-ore")==12,
  "pre-existing unrelated raw materials disappeared")
for _,item in ipairs({"gun-turret","firearm-magazine",
    "stone-wall","repair-pack"}) do
  local wanted=0
  for _,order in ipairs(supply) do
    if order[1]==item then wanted=order[2] end
  end
  assert(chest.get_item_count(item)>=wanted,
    "critical defense inventory was staged out of planner reach")
end
-- All slots now contain required military supply; secondary coal and iron
-- must live in the REAL depot rather than overwrite those committed stacks.
assert(overflow.get_item_count("iron-plate")==80
    and overflow.get_item_count("coal")==40,
  "full stock must physically stage optional support outside the station")
local snapshot={}
for _,order in ipairs(supply) do
  snapshot[order[1]]=chest.get_item_count(order[1])
    +overflow.get_item_count(order[1])
end
-- Retrying the supply plan must recognize existing physical stock, rather
-- than manufacture an extra full batch at every test pulse.
M.test_prestock_defense(station,chest,supply)
for _,order in ipairs(supply) do
  local item=order[1]
  assert(chest.get_item_count(item)+overflow.get_item_count(item)
      ==snapshot[item] or item=="iron-plate" or item=="coal",
    "repeated stocking duplicated a defense supply: "..item)
end
print("[combat-supply-prestock] PASS real chest overflow, preserved custody")
