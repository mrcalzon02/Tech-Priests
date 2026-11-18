-- Test alternative split positions without editing ordinary prototypes.
local donor=data.raw.thruster.thruster
for _,family in ipairs({'void-fusion-thruster','large-void-fusion-thruster'}) do
  for _,split in ipairs({0,0.5,1}) do
    local p=table.deepcopy(data.raw.thruster[family])
    p.name=family..'-half-probe-'..tostring(split):gsub('%.','p')
    local hw,hh=p.tile_width/2,p.tile_height/2
    p.collision_box={{-hw+0.05,-hh+0.05},{hw-0.05,0}}
    local rules=table.deepcopy(donor.tile_buildability_rules)
    for _,rule in pairs(rules) do
      local layers=rule.required_tiles and rule.required_tiles.layers
      if layers and layers.ground_tile then
        rule.area={{-hw+0.2,-hh+0.2},{hw-0.2,split-0.2}}
      elseif layers and layers.empty_space then
        rule.area={{-hw+0.2,split+0.2},{hw-0.2,90.3}}
      end
    end
    p.tile_buildability_rules=rules
    data:extend{p}
  end
end
