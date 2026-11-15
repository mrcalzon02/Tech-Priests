local visuals=require('scripts.bunker_family_visuals')
local names={'autocannon','lobber','energy-dish','chicago-piano','twin-minigun','twin-cannon'}
local teams={{'Red',{r=.95,g=.12,b=.08}},{'Blue',{r=.08,g=.35,b=1}},{'Green',{r=.12,g=.9,b=.2}},{'Gold',{r=1,g=.65,b=.05}}}
script.on_init(function()
  local s=game.create_surface('bunker-team-colour',{default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  s.always_day=true;s.request_to_generate_chunks({16,10},3);s.force_generate_chunk_requests()
  local tiles={};for x=-8,43 do for y=-7,28 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
  storage.team_mask={sites={},surface=s}
  for row,team in ipairs(teams) do
    local force=game.create_force('tp-mask-'..team[1]);force.custom_color=team[2]
    for _,other in pairs(game.forces) do force.set_cease_fire(other,true);other.set_cease_fire(force,true) end
    for col,suffix in ipairs(names) do
      local gun=s.create_entity{name='tech-priests-bunker-'..suffix,position={(col-1)*7,(row-1)*7},force=force,direction=(row-1)*4}
      assert(gun and gun.valid,'Missing weapon '..suffix)
      local c=gun.force.color;assert(math.abs(c.r-team[2].r)<.001 and math.abs(c.g-team[2].g)<.001 and math.abs(c.b-team[2].b)<.001,'Force color mismatch')
      storage.team_mask.sites[#storage.team_mask.sites+1]={gun=gun,weapon=suffix,force=force.name,color=c,direction=gun.direction}
      if row==1 then rendering.draw_text{surface=s,target={(col-1)*7,-3.5},text=suffix,color={1,1,1},alignment='center',scale=1.3} end
    end
    rendering.draw_text{surface=s,target={-4,(row-1)*7},text=team[1],color=team[2],scale=1.5,alignment='center'}
  end
  visuals.init()
end)
script.on_event(defines.events.on_tick,function(e)
  visuals.tick(e)
  if e.tick==20 then
    local p=storage.team_mask;local report={status='PASS',sites={},mask_scope='Four corner stanchions',cannon_art='Real native preview; mechanism animation capture in progress'}
    for _,site in ipairs(p.sites) do report.sites[#report.sites+1]={weapon=site.weapon,force=site.force,color=site.gun.force.color,direction=site.gun.direction} end
    helpers.write_file('bunker-team-colour/result.json',helpers.table_to_json(report),false)
    if GRAPHICAL then
      game.take_screenshot{surface=p.surface,position={17.5,10.5},resolution={1600,1100},zoom=1.1,
        path='bunker-team-colour/all-six-forces.png',show_gui=false,show_entity_info=false}
      game.tick_paused=true
    end
  end
end)
