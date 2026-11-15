local m=data.raw['assembling-machine']['tp-mh7-review-forge']
if m then
 local root='__tp-mh7-forge-audio__/sound/'
 m.working_sound={sound={filename=root..'forge-working.ogg',volume=.70,audible_distance_modifier=2,priority=40,preload=true},
  idle_sound={filename=root..'forge-idle.ogg',volume=.09,audible_distance_modifier=.75},
  activate_sound={filename=root..'forge-start.ogg',volume=.65,audible_distance_modifier=1.75},
  deactivate_sound={filename=root..'forge-stop.ogg',volume=.55,audible_distance_modifier=1.5},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_FORGE_AUDIO_BOUND')
end
