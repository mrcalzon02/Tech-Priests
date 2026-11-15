local m=data.raw['assembling-machine']['tp-mh7-review-fabricator']
if m then
 local root='__tp-mh7-fabricator-audio__/sound/'
 m.working_sound={sound={filename=root..'fabricator-working.ogg',volume=.70,audible_distance_modifier=1.8,priority=30,preload=true},
  idle_sound={filename=root..'fabricator-idle.ogg',volume=.08,audible_distance_modifier=.75},
  activate_sound={filename=root..'fabricator-start.ogg',volume=.55,audible_distance_modifier=1.5},
  deactivate_sound={filename=root..'fabricator-stop.ogg',volume=.45,audible_distance_modifier=1.25},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_FABRICATOR_AUDIO_BOUND')
end
