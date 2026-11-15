local m=data.raw['assembling-machine']['tp-mh7-review-crucible']
if m then
 local root='__tp-mh7-crucible-audio__/sound/'
 m.working_sound={sound={filename=root..'crucible-working.ogg',volume=.65,audible_distance_modifier=2,priority=40,preload=true},
  idle_sound={filename=root..'crucible-idle.ogg',volume=.10,audible_distance_modifier=.75},
  activate_sound={filename=root..'crucible-start.ogg',volume=.70,audible_distance_modifier=1.75},
  deactivate_sound={filename=root..'crucible-stop.ogg',volume=.60,audible_distance_modifier=1.5},
  match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
 log('TP_MH7_CRUCIBLE_AUDIO_BOUND')
end
