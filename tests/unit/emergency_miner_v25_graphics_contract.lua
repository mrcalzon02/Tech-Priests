-- V25 graphics contract. Run from repository root with texlua.
local dir='tech-priests_src/graphics/entity/emergency-miner-v25/'
local original='tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png'
local function be32(s,i)
  local a,b,c,d=s:byte(i,i+3)
  return ((a*256+b)*256+c)*256+d
end
local function dims(file,w,h)
  local f=assert(io.open(dir..file,'rb'),'missing V25 asset '..file)
  local data=f:read(24)
  f:close()
  assert(data:sub(1,8)=='\137PNG\r\n\026\n','not PNG '..file)
  assert(be32(data,17)==w and be32(data,21)==h,'wrong atlas dimensions '..file)
end
for _,n in ipairs({'activity-hr.png','idle-hr.png'}) do dims(n,4096,1024) end
for _,n in ipairs({'activity.png','idle.png'}) do dims(n,2048,512) end
dims('icon-128.png',128,128)
dims('icon-64.png',64,64)
local old=assert(io.open(original,'rb'),'original sprite rollback removed')
old:close()
local miner={name='tech-priests-emergency-miner',graphics_set={},
  crafting_categories={'tech-priests-emergency-mining'},
  energy_source={type='burner'},collision_box={{-.5,-.5},{.5,.5}}}
_G.data={raw={['assembling-machine']={['tech-priests-emergency-miner']=miner},
  item={['tech-priests-emergency-miner']={}},
  recipe={['tech-priests-emergency-miner']={}}}}
assert(loadfile('tech-priests_src/prototypes/generated_graphics/emergency-miner-v25.lua'))()
for direction,row in pairs({north=0,east=3,south=2,west=1}) do
  for _,state in ipairs({'animation','idle_animation'}) do
    local view=assert(miner.graphics_set[state][direction])
    assert(view.frame_count==16 and view.line_length==16)
    assert(view.width==256 and view.height==256 and view.y==row*256)
    assert(math.abs(view.animation_speed-8/60)<1e-9 and view.scale==0.238)
  end
end
assert(miner.crafting_categories[1]=='tech-priests-emergency-mining')
assert(miner.energy_source.type=='burner')
assert(miner.graphics_set.animation.north.filename:find('activity%-hr%.png$'))
assert(miner.graphics_set.idle_animation.north.filename:find('idle%-hr%.png$'))
print('EMERGENCY_MINER_V25_GRAPHICS_CONTRACT_PASS')
