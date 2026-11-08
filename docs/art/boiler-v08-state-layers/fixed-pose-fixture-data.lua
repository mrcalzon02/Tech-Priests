-- Isolated render comparison only: same source pose, original full image vs layers.
local source=assert(data.raw.boiler['tech-priests-emergency-boiler'])
for _,kind in ipairs({'reference','candidate'}) do
  local p=table.deepcopy(source)
  p.name='boiler-layer-'..kind
  p.next_upgrade=nil
  p.energy_source.smoke=nil -- Remove unrelated randomly positioned native smoke.
  for _,direction in ipairs({'north','east','south','west'}) do
    local picture=p.pictures[direction]
    local activity=table.deepcopy(picture.fire)
    assert(activity.frame_count==96 and activity.line_length==12)
    activity.frame_count=1;activity.line_length=1;activity.y=activity.y+512
    if kind=='reference' then
      activity.filename=activity.filename:gsub('%-activity%.png$','-working.png')
      p.pictures[direction]={structure=activity}
    else
      picture.fire=activity
    end
  end
  data:extend{p}
end
