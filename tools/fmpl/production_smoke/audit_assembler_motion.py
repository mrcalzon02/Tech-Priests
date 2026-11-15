"""Evaluate distinct moving assembler subassemblies, including nested head tools."""
import argparse
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_fabricator_motion import geometry
from mh7_machine_scene import sha
from electrolyzer_state_clips import activate_imported_clip


def assembly(obj):
    name=obj.name.split(' | ')[-1]
    if name.startswith('cap slide piston '):return name
    for token in ('telescoping pellet fill tube','annular cap sealing punch','telescoping hollow sealing ram','meter connecting rod'):
        if token in name:return token
    parent=obj
    while parent:
        name=parent.name.split(' | ')[-1]
        if any(t in name for t in ('cap short lift','cap horizontal slide','supported pellet metering spindle','meter gate slide control')):return name
        if 'head X index control' in name:return 'head carriage'
        parent=parent.parent
    return 'static'


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True);ap.add_argument('--glb');ap.add_argument('--substeps',type=int,default=4)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve motion evidence')
    bpy.ops.wm.open_mainfile(filepath=str(source));end=bpy.context.scene.frame_end
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());declared={frozenset((r['a'],r['b'])):r['label'] for r in receipt['contacts']}
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
    s=bpy.context.scene;s.render.fps=24
    if args.glb:activate_imported_clip(s,'idle')
    s.frame_set(0);bpy.context.view_layer.update();objects=[o for o in s.objects if o.type=='MESH'];groups={o:assembly(o) for o in objects}
    fixed={o:geometry(o) for o in objects if groups[o]=='static'};moving=[o for o in objects if groups[o]!='static'];moving_set=set(moving)
    pairs=[(a,b) for i,a in enumerate(objects) for b in objects[i+1:] if groups[a]!=groups[b] and (a in moving_set or b in moving_set)]
    samples=[0]+[1+i/args.substeps for i in range((end-1)*args.substeps+1)];hits={};last_x=None;maximum_head_speed=0;travel=next(o for o in s.objects if 'head X index control' in o.name)
    for index,frame in enumerate(samples):
        if args.glb:activate_imported_clip(s,'idle' if frame==0 else 'working')
        time=max(0,frame-1) if args.glb else frame;s.frame_set(int(time),subframe=time-int(time));bpy.context.view_layer.update()
        x=travel.matrix_world.translation.x
        if index>1:maximum_head_speed=max(maximum_head_speed,abs(x-last_x)*24*args.substeps)
        last_x=x
        trees={**fixed,**{o:geometry(o) for o in moving}}
        for a,b in pairs:
            ta,ba=trees[a];tb,bb=trees[b]
            if any(min(ba[i][1],bb[i][1])-max(ba[i][0],bb[i][0])<.0001 for i in range(3)):continue
            overlap=ta.overlap(tb)
            if overlap:
                key=(a.name,b.name)
                if key not in hits:hits[key]=dict(a=a.name,b=b.name,groups=[groups[a],groups[b]],declared_contact=declared.get(frozenset(key)),frames=[],maximum_triangle_pairs=0)
                row=hits[key];row['frames'].append(frame);row['maximum_triangle_pairs']=max(row['maximum_triangle_pairs'],len(overlap))
        if index%(48*args.substeps)==0:print('ASSEMBLER_MOTION',frame,len(hits),'CONTACT_PAIRS',flush=True)
    for row in hits.values():row['review']=row['declared_contact']
    unexpected=[r for r in hits.values() if not r['review']]
    report=dict(source_sha256=sha(source),glb_sha256=sha(args.glb) if args.glb else None,source_frame_end=end,samples=len(samples),sample_interval_frames=1/args.substeps,
                maximum_head_index_speed_tiles_per_second=maximum_head_speed,reviewed_contacts_passed=not unexpected,unexpected_pairs=len(unexpected),intersection_pairs=list(hits.values()),
                scope='Evaluated world-space triangle intersections at quarter-frame intervals across distinct cap slides/lifts, rods, filling nozzle, sealing punch/ram, metering crank/gate/conrod, moving head frame and static body. Declared contacts remain explicit. Does not certify containment, continuous unsampled intervals or complete granular flow.')
    out.write_text(json.dumps(report,indent=2)+'\n')
    for r in hits.values():print('CONTACT',r['a'].split(' | ')[-1],'/',r['b'].split(' | ')[-1],'FRAMES',min(r['frames']),max(r['frames']),'COUNT',len(r['frames']),'DECLARED',r['review'],flush=True)
    print('MAXIMUM_HEAD_SPEED',maximum_head_speed,flush=True)


if __name__=='__main__':main()
