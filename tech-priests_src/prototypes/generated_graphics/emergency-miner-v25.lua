-- Owner-approved Emergency Miner V25 - Factorio 2.1 CraftingMachineGraphicsSet.
-- This bootstrap pseudo-miner is an assembling machine, not a mining-drill.
-- Preserve its recipes, collision, energy policy, pipes and station behavior.
local target=assert(data.raw["assembling-machine"] and
  data.raw["assembling-machine"]["tech-priests-emergency-miner"],
  "Approved V25 Emergency Miner prototype is missing")
local root="__tech-priests__/graphics/entity/emergency-miner-v25/"
-- One unchanged FMPL 45-degree camera; rotate the original machine.
-- Blender positive yaw maps E/W opposite to Factorio, as for the boiler.
local rows={north=0,east=3,south=2,west=1}
local order={"north","east","south","west"}
local function view(state,dir)
  local row=assert(rows[dir],"Unknown Emergency Miner orientation")
  return {
    filename=root..state.."-hr.png",
    priority="high",
    width=256,height=256,x=0,y=row*256,
    frame_count=16,line_length=16,
    animation_speed=8/60,run_mode="forward",
    scale=0.238,shift={0,-0.05},
    allow_reducing_frames=false
  }
end
local active,idle={},{}
for _,dir in ipairs(order) do
  active[dir]=view("activity",dir)
  idle[dir]=view("idle",dir)
end
target.graphics_set={
  animation=active,
  idle_animation=idle,
  always_draw_idle_animation=false,
}
target.graphics_set_flipped=nil
target.animation=nil
target.animations=nil
target.match_animation_speed_to_activity=false
target.animation_random_start_frame=false
local icon=root.."icon-128.png"
target.icon,target.icons,target.icon_size=icon,nil,128
for _,kind in ipairs({"item","recipe"}) do
  local item=(data.raw[kind] or {})[target.name]
  if item then item.icon,item.icons,item.icon_size=icon,nil,128 end
end
