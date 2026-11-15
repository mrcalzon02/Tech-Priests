"""Shared authored-state export and explicit imported glTF clip selection."""
import bpy


def prepare_state_tracks(scene):
    objects=[o for o in scene.objects if o.animation_data and o.animation_data.action]
    scene.frame_set(0);bpy.context.view_layer.update()
    idle={o:(o.location.copy(),o.scale.copy()) for o in objects}
    for ob in objects:
        work=ob.animation_data.action;work.use_fake_user=True
        ob.animation_data_clear()
        ob.location,ob.scale=idle[ob]
        for frame in (0,1):
            ob.keyframe_insert(data_path='location',frame=frame)
            ob.keyframe_insert(data_path='scale',frame=frame)
        standby=ob.animation_data.action;standby.name='TP Electrolyzer standby | '+ob.name
        ob.animation_data.action=None
        for name,action,start,end in (('working',work,1,97),('idle',standby,0,1)):
            track=ob.animation_data.nla_tracks.new();track.name=name
            strip=track.strips.new(name,start,action)
            strip.action_frame_start=start;strip.action_frame_end=end
            strip.frame_start=start;strip.frame_end=end;strip.extrapolation='NOTHING'
    scene.frame_set(25);bpy.context.view_layer.update()
    return len(objects)


def activate_imported_clip(scene,name):
    count=0
    for ob in scene.objects:
        ad=ob.animation_data
        if not ad:continue
        tracks=[t for t in ad.nla_tracks if t.name==name and t.strips]
        if len(tracks)>1:raise RuntimeError('Ambiguous imported clip '+name)
        for track in ad.nla_tracks:track.mute=True
        if tracks:
            strip=tracks[0].strips[0]
            ad.action=strip.action;ad.action_slot=strip.action_slot;count+=1
        else:
            ad.action=None
    bpy.context.view_layer.update()
    return count
