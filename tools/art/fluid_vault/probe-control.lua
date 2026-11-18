local ID='tech-priests-stone-cache-pressurized-fluid-vault'
script.on_init(function()
 local s=game.surfaces[1];s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();storage.rows={}
 for i,d in ipairs{0,4,8,12}do
  local p={x=(i-1)*8+.5,y=.5};local e=s.create_entity{name=ID,position=p,direction=d,force='player'};local axis=d%8==0 and {0,1} or {1,0};local pipes={};local place={}
  for _,sign in ipairs{-1,1}do local q={p.x+axis[1]*2*sign,p.y+axis[2]*2*sign};place[#place+1]=s.can_place_entity{name='pipe',position=q,force='player'};pipes[#pipes+1]=s.create_entity{name='pipe',position=q,force='player'}end
  storage.rows[#storage.rows+1]={entity=e,pipes=pipes,requested=d,place=place}
 end
end)
script.on_event(defines.events.on_tick,function()
 if game.tick~=3 then return end
 local rows={}
 for _,r in ipairs(storage.rows)do
  local e=r.entity;local checks={};for _,p in ipairs(r.pipes)do checks[#checks+1]=p.get_fluid_segment_id(1)==e.get_fluid_segment_id(1) end
  local row={requested=r.requested,actual=e.direction,position=e.position,tile_width=e.prototype.tile_width,tile_height=e.prototype.tile_height,capacity=e.get_fluid_capacity(1),ordinary_pipe_placement=r.place,connected=checks}
  for _,p in ipairs(r.pipes)do p.destroy()end
  row.rotation_1=e.rotate{} and e.direction;row.rotation_2=e.rotate{} and e.direction;rows[#rows+1]=row
 end
 helpers.write_file('fluid-vault/preflight.json',helpers.table_to_json(rows),false)
end)
