-- Audio-only extension: preserved geometry, recipes and animation graphics.
local ROOT='__tp-mh7-machinery-audio__/sound/'
local rows={
 {'tp-mh7-review-purifier','purifier-working.ogg',.46,1.25,96},
 {'tp-mh7-review-electrolyzer','electrolyzer-working.ogg',.40,1.15,104},
 {'tp-mh7-review-compressor','compressor-working.ogg',1.15,3.5,16},
}
for _,row in ipairs(rows) do
 local entity=data.raw['assembling-machine'][row[1]]
 if entity then
  entity.working_sound={sound={filename=ROOT..row[2],volume=row[3],audible_distance_modifier=row[4],priority=row[5],preload=true},
   match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
  if row[1]=='tp-mh7-review-compressor' then
   entity.working_sound.idle_sound={filename=ROOT..'compressor-idle.ogg',volume=.14,audible_distance_modifier=.85,priority=160}
   entity.working_sound.activate_sound={filename=ROOT..'compressor-start.ogg',volume=.90,audible_distance_modifier=3,priority=24}
   entity.working_sound.deactivate_sound={filename=ROOT..'compressor-stop.ogg',volume=.82,audible_distance_modifier=2.5,priority=32}
  end
  log('TP_MH7_AUDIO_BOUND '..row[1]..' gain='..row[3]..' range='..row[4])
 end
end
