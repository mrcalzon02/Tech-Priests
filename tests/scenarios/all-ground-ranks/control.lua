-- Tech-Priests deterministic ground-rank integration fixture.
-- Scenario intentionally places Cogitator Stations rather than creating priests
-- directly: the mod's normal station/priest lifecycle must create the pairs.
local stations = {
  {name="junior-cogitator-station", x=0, y=0},
  {name="intermediate-cogitator-station", x=24, y=0},
  {name="senior-cogitator-station", x=48, y=0},
  {name="planetary-magos-cogitator-station", x=72, y=0},
}
local function emit(message) log("[TP-GROUND-RANK-TEST] "..message) end
script.on_init(function()
  local surface=game.surfaces[1]
  local force=game.forces.player
  for _,s in ipairs(stations) do
    if not prototypes.entity[s.name] then error("Missing station prototype: "..s.name) end
    local pos={x=s.x,y=s.y}
    surface.request_to_generate_chunks(pos,2)
  end
  surface.force_generate_chunk_requests()
  for _,s in ipairs(stations) do
    local pos={x=s.x,y=s.y}
    local entity=surface.create_entity{name=s.name,position=pos,force=force,raise_built=true}
    if not (entity and entity.valid) then error("Unable to place "..s.name) end
    emit("placed "..s.name.." unit="..tostring(entity.unit_number))
  end
end)
script.on_nth_tick(300,function()
  local surface=game.surfaces[1]
  local missing={}
  for _,s in ipairs(stations) do
    local station=surface.find_entities_filtered{name=s.name,position={s.x,s.y},radius=3,force=game.forces.player}[1]
    if not (station and station.valid) then missing[#missing+1]=s.name end
  end
  if #missing>0 then error("Ground-rank fixture missing stations: "..table.concat(missing,",")) end
  local tp=storage.tech_priests
  local paired=0
  if tp and tp.pairs_by_station then
    for _,s in ipairs(stations) do
      local entities=surface.find_entities_filtered{name=s.name,position={s.x,s.y},radius=3,force=game.forces.player}
      local e=entities[1]
      local pair=e and tp.pairs_by_station[e.unit_number]
      if not (pair and pair.priest and pair.priest.valid) then
        error("Ground-rank station lacks living priest: "..s.name)
      end
      paired=paired+1
    end
  else
    error("Tech-Priests pair registry unavailable")
  end
  emit("PASS ground ranks with live pairs="..paired.." tick="..game.tick)
  script.on_nth_tick(300,nil)
end)
