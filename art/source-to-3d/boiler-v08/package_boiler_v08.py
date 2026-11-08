from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageStat
import json,zipfile,hashlib,shutil,subprocess
R=Path(__file__).resolve().parent;D=R/'boiler_v08';names=[D/'preview_frames'/('frame_%03d.png'%f) for f in range(1,97,2)]
if not (D/'Preview_Render.json').exists():
 chunks=[json.loads((D/('Preview_Render_Chunk%d.json'%i)).read_text()) for i in range(3)]
 combined=sorted(f for x in chunks for f in x['frames']);assert combined==list(range(1,97,2))
 (D/'Preview_Render.json').write_text(json.dumps({'engine':chunks[0]['engine'],'frames':combined,'seconds':max(x['seconds'] for x in chunks),'parallel_render_workers':3,'resolution':chunks[0]['resolution'],'playback_fps':12,'loop_seconds':4,'native_volume_detail_unchanged':True},indent=2))
assert all(p.exists() for p in names),'Preview render incomplete'
config=json.loads((D/'Preview_Render.json').read_text());assert config['engine']=='CYCLES','Draft Eevee frames must not be packaged as an appearance reference'
frames=[Image.open(p).convert('RGB') for p in names];size=tuple(config['resolution']);assert all(im.size==size for im in frames)
durations=[80,80,90]*16
frames[0].save(D/'Boiler_V08_Operating_Loop.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','12','-pattern_type','glob','-i',str(D/'preview_frames/frame_*.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(D/'Boiler_V08_Operating_Loop.mp4')],check=True)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',19);sheet=Image.new('RGB',(size[0]*4,size[1]+36),(37,40,42));draw=ImageDraw.Draw(sheet)
for i,k in enumerate([0,12,24,36]):sheet.paste(frames[k],(i*size[0],36));draw.text((i*size[0]+12,10),'%.1f s'%(k/12),font=font,fill=(235,236,237))
sheet.save(D/'Boiler_V08_Animation_Contact.png')
variation=[sum(ImageStat.Stat(ImageChops.difference(frames[i],frames[i-1])).mean) for i in range(1,len(frames))];assert min(variation)>.001
check={'preview_frames':len(frames),'resolution':list(size),'duration_milliseconds':sum(durations),'all_adjacent_frames_change':True,'minimum_adjacent_pixel_difference':min(variation),'source_pose_rate':24,'preview_rate':12};(D/'Preview_Validation.json').write_text(json.dumps(check,indent=2))
if (R/'goal_animation_base.json').exists():
 goal=json.load(open(R/'goal_animation_base.json'));a=next(a for a in goal['assets'] if a['id']=='emergency-boiler');a['stages']['animation']='V08: four-second 24fps operating loop built from user-supplied V07b. Eleven glow/button targets animate, three smaller canister assemblies rattle, and two steam bursts plus residual wisps vent from the actual added rear-tank top nozzle. No simulation cache dependency.';a['stages']['geometry']='User-supplied V07b geometry is authoritative for V08. All 270 source mesh vertex arrays preserved; rest world transforms match within floating-point precision.';a['stages']['native_validation']='V08 reopened; source geometry preserved; exact loop closure, emission changes, rig movement and steam puff progression checked. Preview is a 48-frame, four-second 12fps review loop.';a['stages']['visual_acceptance']='V08 animation ready for first motion review; no production atlas/runtime integration claimed.';a['artifacts'].update(native='tech_priests_emergency_boiler_v08_animated.blend',native_library_file_id='libfile_472d55643ae4819189e12200eb66d4ca',animation_preview='Boiler_V08_Operating_Loop.gif',animation_video='Boiler_V08_Operating_Loop.mp4',animation_record='Boiler_V08_Animation_Record.json',validation='Boiler_V08_Validation.json',package='Boiler_V08_Animation_Package.zip');a['artifacts']['static_export_previous']=a['artifacts'].pop('export',None);a['artifacts']['comparison']='Boiler_V08_Animation_Contact.png';a['animation_camera']={'count':1,'name':'BOILER_FACTORIO_EXPORT_45'};a['next_action']='Review V08 flicker, button pulses, canister rattle and nozzle steam timing. Four-direction production capture and runtime integration remain pending.';(R/'Tech_Priests_3D_Reconstruction_Goal.json').write_text(json.dumps(goal,indent=2)+'\n')
manifest={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in D.rglob('*') if p.is_file() and p.suffix!='.blend1' and p.name not in ['SHA256.json','Preview_Test.json']};(D/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
repo=R/'tech-priests-repo/art/source-to-3d/boiler-v08';repo.mkdir(exist_ok=True)
for name in ['animate_boiler_v08.py','preview_boiler_v08.py','validate_boiler_v08.py','package_boiler_v08.py','cleanup_boiler_v08_cameras.py']:shutil.copyfile(R/name,repo/name)
for name in ['README.md','SHA256.json','Boiler_V08_Animation_Record.json','Boiler_V08_Validation.json','Preview_Render.json','Preview_Validation.json','Camera_Cleanup.json']:shutil.copyfile(D/name,repo/name)
with zipfile.ZipFile(R/'Boiler_V08_Animation_Package.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in D.rglob('*'):
  if p.is_file() and p.suffix!='.blend1' and p.name!='Preview_Test.json':z.write(p,p.relative_to(R))
 for name in ['animate_boiler_v08.py','preview_boiler_v08.py','validate_boiler_v08.py','package_boiler_v08.py','cleanup_boiler_v08_cameras.py']:z.write(R/name,name)
 p=R/'upload/tech_priests_emergency_boiler_v07b.blend';z.write(p,p.relative_to(R))
print('ANIMATION_PACKAGE_READY',check)
