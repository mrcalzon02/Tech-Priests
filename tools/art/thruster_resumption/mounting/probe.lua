-- Disposable native placement probes, never a normal save/profile.
script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true)
    remote.call('freeplay','set_disable_crashsite',true)
  end
  local rows = {}
  for _, family in ipairs({'void-fusion-thruster','large-void-fusion-thruster'}) do
    for _, split in ipairs({0,0.5,1}) do
      local tag = tostring(split):gsub('%.','p')
      local name = family..'-half-probe-'..tag
      local platform = game.forces.player.create_space_platform{
        name=name,planet='nauvis',starter_pack='space-platform-starter-pack'}
      platform.apply_starter_pack(true)
      local surface=platform.surface
      surface.request_to_generate_chunks({0,0},3)
      surface.force_generate_chunk_requests()
      local odd=family=='void-fusion-thruster'
      local position=odd and {16.5,0.5} or {16,0}
      local row={name=name,split=split,position=position,probes={}}
      for last=-5,5 do
        local tiles={}
        for x=-4,24 do for y=-8,9 do
          tiles[#tiles+1]={name=(x<12 or y<=last) and 'space-platform-foundation' or 'empty-space',position={x,y}}
        end end
        surface.set_tiles(tiles)
        row.probes[#row.probes+1]={last_foundation_row=last,
          legal=surface.can_place_entity{name=name,position=position,
            direction=defines.direction.north,force='player'}}
      end
      rows[#rows+1]=row
    end
  end
  helpers.write_file('half-mount-probe.json',helpers.table_to_json{rows=rows},false)
end)
