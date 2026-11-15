"""Independent evaluated geometry/kinematics checks for the compressor pilot."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import tree,bounds,sha
from verify_purifier_v14 import gap
from audit_electrolyzer_v01 import mesh_stats,port_probe


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Keep independent readback evidence')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    prefix='TP Hydrogen Compressor V01 | '
    def ob(label):return s.objects[prefix+label]
    receipt=json.loads((source.parent/'construction-receipt.json').read_text())
    ports=json.loads((source.parent/'port_manifest.json').read_text())['ports']
    contacts=[];errors=[]
    pairs=list(receipt['contacts'])
    for x in (-.72,0,.72):
        for y in (-.79,-.36):
            for dx in (-.13,.13):pairs.append(dict(a=ob('crosshead guide '+str((x,dx))).name,b=ob('guide bearing tie '+str((x,y))).name,label='guide rail carried at bearing tie'))
        for y in (.05,.8):pairs.append(dict(a=ob('closed horizontal compressor cylinder '+str(x)).name,b=ob('machined concave saddle '+str((x,y))).name,label='cylinder seated on machined saddle'))
    for row in pairs:
        a,b=(s.objects.get(row[k]) for k in ('a','b'));distance=gap(a,b) if a and b else None
        contacts.append(dict(**row,gap_tiles=distance,passed=distance is not None and distance<=.015))
    if any(not r['passed'] for r in contacts):errors.append('assembly support/contact')
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    stats=mesh_stats(s);bores=port_probe(s,ports)
    if not bores['passed']:errors.append('external bores')
    if stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('mesh validity')
    # Surface intersection checks name real disjoint pairs only. Expected pin,
    # hub, cylinder mounting and bearing contacts are checked separately.
    collisions=[];motion=[];checks=0;matrices={}
    fixed_tokens=('common crankshaft main journal','crank cheek web','guide bearing tie','crosshead guide','guide bearing pedestal','front crank guard')
    fixed=[o for o in meshes if any(t in o.name for t in fixed_tokens)]
    moving=[o for o in meshes if 'connecting rod shaft' in o.name or 'crosshead retained wrist pin' in o.name]
    flywheel=[o for o in meshes if any(t in o.name for t in ('flywheel machined rim','flywheel radial spoke'))]
    guards=[o for o in meshes if any(t in o.name for t in ('fixed flywheel outer guard','flywheel guard footing','shaft bearing tower','shaft bearing cap seat'))]
    working_end=s.frame_end
    for frame in range(1,working_end+1,(working_end-1)//16):
        s.frame_set(frame);bpy.context.view_layer.update();cache={o:tree(o) for o in set(fixed+moving+flywheel+guards)}
        for a,targets in [(a,fixed) for a in moving]+[(a,guards) for a in flywheel]:
            for b in targets:
                checks+=1
                overlap=cache[a].overlap(cache[b])
                if overlap:collisions.append(dict(frame=frame,a=a.name,b=b.name,triangle_pairs=len(overlap)))
        row=[]
        for x in (-.72,0,.72):
            pin=ob('eccentric crank pin '+str(x)).matrix_world.translation.copy()
            wrist=ob('crosshead retained wrist pin '+str(x)).matrix_world.translation.copy()
            link=ob('connecting rod shaft '+str(x))
            ends=[link.matrix_world @ Vector((0,0,z)) for z in (-.5,.5)]
            endpoint_error=min(max((ends[0]-pin).length,(ends[1]-wrist).length),max((ends[1]-pin).length,(ends[0]-wrist).length))
            radius=((pin.y+1.25)**2+(pin.z-.78)**2)**.5
            length=(pin-wrist).length
            valid=abs(radius-.12)<1e-5 and abs(length-.67)<1e-5 and endpoint_error<1e-5 and abs(wrist.z-.78)<1e-5 and -.70001<=wrist.y<=-.45999
            row.append(dict(x=x,actual_pin=list(pin),actual_wrist=list(wrist),radius=radius,rod_length=length,endpoint_error=endpoint_error,passed=valid))
        motion.append(dict(frame=frame,units=row))
        if frame in (1,working_end):matrices[frame]={o.name:[float(c) for r in o.matrix_world for c in r] for o in meshes}
    if collisions:errors.append('moving part surface intersection')
    if any(not unit['passed'] for row in motion for unit in row['units']):errors.append('actual slider-crank geometry')
    loop=max(abs(a-b) for name,values in matrices[1].items() for a,b in zip(values,matrices[working_end][name]))
    if loop>1e-4:errors.append('working loop closure')
    # The fixed bearing seat must not fill its own shaft bore.
    bearing_hits=[]
    for x in (-1.18,1.18):
        seat=tree(ob('shaft bearing cap seat '+str(x)))
        hit=seat.ray_cast(Vector((x-.2,-1.25,.76)),Vector((1,0,0)),.4)
        if hit[0] is not None:bearing_hits.append(dict(x=x,point=list(hit[0])))
    if bearing_hits:errors.append('shaft bearing seat closes shaft core')
    s.frame_set(25);bpy.context.view_layer.update()
    result=dict(passed=not errors,errors=errors,source_sha256=sha(source),native_stats=stats,bounds=bounds(meshes),
        external_bores=bores,contacts=contacts,motion=motion,loop_world_matrix_error=loop,
        disjoint_surface_pair_checks=checks,collisions=collisions,bearing_core_blockers=bearing_hits,cycle_seconds=(working_end-1)/s.render.fps,
        scope='17 actual poses, named disjoint moving/static surface pairs, actual crank endpoints and support contacts; no structural/pressure certification or native integration claimed')
    (out/'mechanical-readback.json').write_text(json.dumps(result,indent=2)+'\n')
    print('COMPRESSOR_MECHANICS',result['passed'],errors,'collision_count',len(collisions),'failed_contacts',sum(not r['passed'] for r in contacts),flush=True)
    if errors:raise RuntimeError('Inspect failed mechanical-readback.json; preserve source and repair')


if __name__=='__main__':main()
