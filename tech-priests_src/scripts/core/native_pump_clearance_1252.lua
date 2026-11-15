-- Observe one real tree obstructing an installed native water intake.
-- Discovery never mines, moves a priest, creates output or changes a recipe.
local Fluid=require("scripts.core.native_fluidbox_1279")
local M={}
local function valid(e)return e and e.valid end
local function distance(a,b)return(a.x-b.x)^2+(a.y-b.y)^2 end
local function context(p,r)
 if not(p and valid(p.station)and valid(p.priest)and r)then return false end
 local op=p.independent_emergency_operation_0184
 local parent=p.emergency_craft
 if not(op and op.enabled==true and type(parent)=="table"and parent==r.parent
   and parent.facility_only_0647==true and parent.infrastructure_first_0640==true)then return false end
 local pump,load=r.pump,r.load
 if not(valid(pump)and pump.name=="offshore-pump"and pump.type=="offshore-pump"
   and pump.force==p.station.force and pump.surface==p.station.surface
   and p.priest.force==p.station.force and p.priest.surface==p.station.surface
   and valid(load)and load.type=="assembling-machine"
   and load.force==p.station.force and load.surface==p.station.surface
   and r.position and r.port)then return false end
 local radius=math.max(8,math.min(96,tonumber(p.radius)or 28))
 if distance(r.position,p.station.position)>radius*radius then return false end
 local ok,needed=pcall(function()
  local recipe=load.get_recipe()
  return load.energy<=0 and recipe and recipe.name==(parent.output_item or parent.item_name)
 end)
 if not(ok and needed)then return false end
 local box=Fluid.observe(pump);local connections={}
 if box then pcall(function()connections=box.get_pipe_connections(1)or{}end)end
 for _,c in pairs(connections)do
  local port=c.target_position or c.position
  if port and distance(port,r.port)<.0225 and not c.target then return true end
 end
 return false
end
function M.valid_request(p,r)
 if not context(p,r)then return false end
 local tree=r.tree
 if not(valid(tree)and tree.type=="tree"and tree.surface==p.station.surface
   and tree.force and tree.force.name=="neutral"and tree.unit_number==r.tree_unit)then return false end
 local ok,blocked=pcall(function()
  if tree.minable==false then return false end
  local wood=false
  for _,product in pairs(tree.prototype.mineable_properties.products or{})do
   if product.name=="wood"and product.type~="fluid"then wood=true end
  end
  local b=tree.bounding_box;local a,z=b.left_top,b.right_bottom;local port=r.port
  return wood and a.x<=port.x+.29 and z.x>=port.x-.29
   and a.y<=port.y+.29 and z.y>=port.y-.29
   and not p.station.surface.can_place_entity{name="pipe",position=port,force=p.station.force}
 end)
 return ok and blocked==true
end
function M.observe(p,pump,load)
 local current=p.power_setup_tree_clearance_1252
 local active=p.direct_acquisition_task_0336
 if current and active and active.pump_clearance_1252==current then return current end
 if M.valid_request(p,current)then return current end
 local box=Fluid.observe(pump);local connections={}
 if box then pcall(function()connections=box.get_pipe_connections(1)or{}end)end
 for _,c in pairs(connections)do
  local port=c.target_position or c.position
  if port and not c.target then
   local ok,trees=pcall(function()return p.station.surface.find_entities_filtered{
    area={{port.x-.29,port.y-.29},{port.x+.29,port.y+.29}},type="tree",force="neutral",limit=4}end)
   if ok then for _,tree in pairs(trees or{})do
    if valid(tree)then
     local r={tree=tree,tree_unit=tree.unit_number,position={x=tree.position.x,y=tree.position.y},
      pump=pump,load=load,port={x=port.x,y=port.y},parent=p.emergency_craft}
     if M.valid_request(p,r)then p.power_setup_tree_clearance_1252=r;return r end
    end
   end end
  end
 end
 return nil
end
function M.authorized_task(p)
 local r=p and p.power_setup_tree_clearance_1252
 local t=p and p.direct_acquisition_task_0336
 if not(r and t and t.pump_clearance_1252==r and t.output_item=="wood"
   and t.bootstrap_resource_0637==true and context(p,r))then return false end
 local current=t.current and(t.current.entity or t.current.target)
 if current~=r.tree then return false end
 if M.valid_request(p,r)then return true end
 local cargo=p.direct_acquisition_custody_0513
 return not valid(r.tree)and cargo and cargo.item=="wood"
   and(tonumber(cargo.count)or 0)>0 and cargo.native_inventory and cargo.native_inventory.valid or false
end
return M
