local Policy=dofile("tech-priests_src/scripts/core/autonomous_rebuild_policy.lua")
local valid={mode="full-autonomous",maximum_frustration=true,
  player_order_active=false,player_plan_locked=false,parent_order_active=false,
  generation=2,proposal_generation=2,target_owned_autonomous=true,
  same_force_surface=true,player_built=false,player_blueprint_structure=false,
  protected=false,committed_task=false,material_custody=false,
  critical_dependency=false,contents_empty=true,replacement_verified=true,
  salvage_capacity_verified=true}
assert(Policy.consider(valid))
for key,value in pairs(valid) do
  local c={};for k,v in pairs(valid) do c[k]=v end
  c[key]=nil;assert(not Policy.consider(c),"unknown accepted: "..key)
  c[key]=type(value)=="boolean" and not value or "invalid"
  assert(not Policy.consider(c),"unsafe accepted: "..key)
end
assert(not Policy.consider())
print("PASS autonomous rebuild proposal fails closed on every missing/unsafe gate")
