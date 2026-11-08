"""Select existing OptiX hardware for this Blender process; never save preferences."""
import bpy,json
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices();selected=[]
for device in prefs.devices:
    device.use=device.type=='OPTIX'
    if device.use:selected.append(device.name)
assert selected,'No existing OptiX device is available'
bpy.context.scene.cycles.device='GPU'
print('LOCAL_OPTIX_PROFILE',json.dumps({'backend':'OPTIX','devices':selected,'blender':bpy.app.version_string,'preferences_saved':False,'sampling_camera_geometry_unchanged':True}),flush=True)
