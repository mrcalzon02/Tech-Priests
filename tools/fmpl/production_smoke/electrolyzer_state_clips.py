"""Shared authored-state export and explicit imported glTF clip selection."""
import bpy


def prepare_state_tracks(scene):
    working_end=scene.frame_end
    objects=[o for o in scene.objects if o.animation_data and o.animation_data.action]
    scene.frame_set(0);bpy.context.view_layer.update()
    idle={o:(o.location.copy(),o.scale.copy(),o.rotation_mode,
        o.rotation_quaternion.copy() if o.rotation_mode=='QUATERNION' else o.rotation_euler.copy()) for o in objects}
    for ob in objects:
        work=ob.animation_data.action;work.use_fake_user=True
        ob.animation_data_clear()
        ob.location,ob.scale,ob.rotation_mode,rotation=idle[ob]
        rotation_channel='rotation_quaternion' if ob.rotation_mode=='QUATERNION' else 'rotation_euler'
        setattr(ob,rotation_channel,rotation)
        for frame in (0,1):
            ob.keyframe_insert(data_path='location',frame=frame)
            ob.keyframe_insert(data_path='scale',frame=frame)
            ob.keyframe_insert(data_path=rotation_channel,frame=frame)
        standby=ob.animation_data.action;standby.name='TP Electrolyzer standby | '+ob.name
        ob.animation_data.action=None
        for name,action,start,end in (('working',work,1,working_end),('idle',standby,0,1)):
            track=ob.animation_data.nla_tracks.new();track.name=name
            strip=track.strips.new(name,start,action)
            strip.action_frame_start=start;strip.action_frame_end=end
            strip.frame_start=start;strip.frame_end=end;strip.extrapolation='NOTHING'
    keys={o.data.shape_keys for o in scene.objects if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.animation_data and o.data.shape_keys.animation_data.action}
    scene.frame_set(0);bpy.context.view_layer.update()
    for key in keys:
        work=key.animation_data.action;work.use_fake_user=True
        values={block:block.value for block in key.key_blocks[1:]};key.animation_data_clear()
        for frame in (0,1):
            for block,value in values.items():block.value=value;block.keyframe_insert(data_path='value',frame=frame)
        standby=key.animation_data.action;standby.name='TP Morph standby | '+key.name;key.animation_data.action=None
        for name,action,start,end in (('working',work,1,working_end),('idle',standby,0,1)):
            track=key.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,start,action)
            strip.action_frame_start=start;strip.action_frame_end=end;strip.frame_start=start;strip.frame_end=end;strip.extrapolation='NOTHING'
    scene.frame_set(25);bpy.context.view_layer.update()
    return len(objects)


def activate_imported_clip(scene,name):
    count=0
    owners=list(scene.objects)+list({o.data.shape_keys for o in scene.objects if o.type=='MESH' and o.data.shape_keys})
    for ob in owners:
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
