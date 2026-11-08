import argparse, pathlib, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont
p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);args=p.parse_args()
r = args.repo.resolve()
w = args.out.resolve();w.mkdir(parents=True,exist_ok=True)
paths = {state: r / f'tech-priests_src/graphics/entity/thetazine-thruster/thetazine-thruster-{state}.png' for state in ['idle','run']}
h = r / 'tech-priests_src/graphics/entity/hydrogen-thruster/hydrogen-thruster-idle.png'
im = {s: Image.open(p).convert('RGBA') for s,p in paths.items()}
hyd = Image.open(h).convert('RGBA')
assert all(v.size == (512,512) for v in im.values())
# Test the shared structural pixels; do not infer the flame or final frame contract.
rect = (0,0,256,230)
diff = np.abs(np.asarray(im['idle'].crop(rect)).astype(int)-np.asarray(hyd.crop(rect)).astype(int))
a = np.asarray(im['idle'].crop(rect))[:,:,3] > 128
b = np.asarray(hyd.crop(rect))[:,:,3] > 128
report = {'status':'SOURCE_CONTRACT_ESTABLISHED_RENDER_AND_NATIVE_GATES_OPEN', 'reference_sha256': {s:hashlib.sha256(p.read_bytes()).hexdigest() for s,p in paths.items()}, 'hydrogen_reference_sha256':hashlib.sha256(h.read_bytes()).hexdigest(), 'shared_upper_body_rectangle':list(rect), 'shared_upper_body_exact_rgba_pixels':int(np.sum(np.all(diff==0,axis=-1))), 'compared_pixels':256*230,'max_rgba_difference':int(diff.max()), 'reference_cells':{'idle':{'count':2,'cell':[256,512]},'run':{'count':2,'cell':[256,512]}}, 'silhouette':'Both source sprites share the same crossbeam, twin canisters, shoulders, six feeds, pressure chamber, winged skull and bell construction. Thetazine has its own two-frame idle/run flame/light artwork and distinct 5x5 native interface. Reusing the verified authored construction is explicit, not an independently recovered historical native model.', 'native_contract':{'direction':'fixed north, not rotatable','footprint':[5,5],'collision_box':[[-2.15,-2.35],[2.15,2.35]],'fuel_cell':[-2,-1],'fuel_mating':[-2.5,-1],'fuel_adjacent_pipe':[-3,-1],'fuel':'thetazine-fuel','oxidizer_cell':[2,-1],'oxidizer_mating':[2.5,-1],'oxidizer_adjacent_pipe':[3,-1],'oxidizer':'water','caps':['pipe-4','pipe-1'],'wire_attachment':'No new wire points invented; existing native definition must be read back before integration.'}, 'pipeline_reconciliation':{'tech_priests_main':'d03e6f288e7ef20fcabcabf5abf9735d26e2c9fb','hb_main':'b02cf5a8d','hb_reference':'tools/factorio-render-pipeline/THRUSTER_ENTITY_ASSEMBLY_R17.md','scope':'HB R17 describes separate conditional body/glow/cap layers in vanilla. It is not Thetazine art authority. No Actions or HB modifications.'}, 'open_gates':['Actual exported mesh/UV/PBR/socket inspection','Viewed exported-artifact renders and scored review','Native pipe-mouth registration and connected/disconnected caps','Complete source-state beauty/emission/plume/shadow capture, atlas and real prototype import','Native graphical proof; no propulsion or behavior tests']}
report['shared_upper_body_alpha_iou_over_128'] = float(np.sum(a & b) / np.sum(a | b))
report['comparison_limit'] = 'RGBA pixels are NOT identical. Near-identical alpha silhouette supports shared visible construction, not original native source identity or final Thetazine appearance approval.'
(w/'source-contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
board=Image.new('RGB',(1024,570),(35,37,39));d=ImageDraw.Draw(board)
for i,(s,index) in enumerate([('idle',0),('idle',1),('run',0),('run',1)]):
 cell=im[s].crop((index*256,0,(index+1)*256,512));board.paste(cell,(i*256,50),cell);d.text((i*256+8,12),f'Legacy {s} {index}',fill='white',font=font)
board.save(w/'legacy-source-states.png')
print(json.dumps({'exact_upper_body_pixels':report['shared_upper_body_exact_rgba_pixels'],'pixels':report['compared_pixels'],'max_difference':report['max_rgba_difference']}))
