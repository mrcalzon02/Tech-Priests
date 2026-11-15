"""Independent crucible contact, real flow-core and protected-fan audit."""
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
from mechanical_routes import rounded_path


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--glb',help='Audit the actual runtime artifact using the source construction contract')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists(): raise FileExistsError('Preserve audit evidence')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()));s=bpy.context.scene
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working');s.frame_set(24);bpy.context.view_layer.update()
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());ports=json.loads((source.parent/'port_manifest.json').read_text())['ports'];contacts=[]
    for row in receipt['contacts']:
        a,b=(s.objects.get(row[k]) for k in ('a','b'));distance=gap(a,b) if a and b else None
        contacts.append(dict(**row,gap_tiles=distance,passed=distance is not None and distance<=.015))
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render];trees={o:tree(o) for o in meshes}
    hits=[];rays=0;transitions=[]
    for route in receipt['process_routes']:
        ob=s.objects[route['mesh']];small=.09 if route['id']=='conditioned_hydrogen_input' else .11
        points=[Vector(v) for v in route['points']] if route.get('sampled_path') else rounded_path(route['points'],small)
        if route.get('reducer_axes_parallel') and not args.glb:
            reducer=s.objects[route['reducer']]
            rings=[[reducer.matrix_world @ v.co for v in list(reducer.data.vertices)[i*64:(i+1)*64]] for i in range(4)]
            centers=[sum(r,Vector())/len(r) for r in rings];axis=(centers[1]-centers[0]).normalized()
            plane_error=max(abs((v-c).dot(axis)) for ring,c in zip(rings,centers) for v in ring)
            radius_error=max(abs((v-c).length-r) for ring,c,r in zip(rings,centers,(.285,small,.245,small*.72)) for v in ring)
            count=len(route['points']);vertices=list(ob.data.vertices);bend_error=0
            for channel,radius in ((0,small),(1,small*.72)):
                for i,point in enumerate(points):
                    ring=[ob.matrix_world @ v.co for v in vertices[(channel*count+i)*40:(channel*count+i+1)*40]]
                    bend_error=max(bend_error,max(abs((v-point).length-radius) for v in ring))
            transitions.append(dict(route=route['id'],axis=list(axis),ring_plane_error=plane_error,reducer_radius_error=radius_error,
                constant_tube_radius_error=bend_error,passed=plane_error<1e-5 and radius_error<1e-5 and bend_error<1e-5))
            # Cover the receiving barrel and reducer, not merely the small line.
        if route.get('reducer_axes_parallel'):
            points.insert(0,Vector(((-1 if points[0].x<0 else 1)*2.195,0,.36)))
        # Extend through the drilled vessel wall into the actual chamber void.
        sign=1 if points[-1].x>0 else -1;points.append(Vector((sign*.82,0,points[-1].z)))
        for start,end in zip(points,points[1:]):
            delta=end-start;direction=delta.normalized();u=direction.cross(Vector((0,0,1)))
            if u.length<.01:u=direction.cross(Vector((0,1,0)))
            u.normalize();v=direction.cross(u).normalized()
            for x,y in ((0,0),(.03,0),(-.03,0),(0,.03),(0,-.03)):
                origin=start+u*x+v*y+direction*.0001;rays+=1
                for other,bvh in trees.items():
                    hit=bvh.ray_cast(origin,direction,max(0,delta.length-.0002))
                    if hit[0] is not None:hits.append(dict(route=route['id'],object=other.name,start=list(start),end=list(end),offset=[x,y],hit=list(hit[0])))
    # Fan blades must clear the shroud and front grill at every sampled pose.
    blades=[o for o in meshes if 'cooling fan swept blade' in o.name]
    fixed=[o for o in meshes if any(t in o.name for t in ('fan front protective guard','cooling fan protective shroud','cooling fan bearing hub','fan spindle retaining washer','fan spindle retained cap'))]
    hub=s.objects.get(receipt.get('fan_rotor_hub',''))
    collisions=[];checks=0;loop={};blade_contacts=[]
    for frame in range(1,194,12):
        s.frame_set(frame-1 if args.glb else frame);bpy.context.view_layer.update()
        for blade in blades:
            bvh=tree(blade)
            if hub:
                distance=gap(blade,hub);blade_contacts.append(dict(frame=frame,blade=blade.name,hub=hub.name,gap=distance,passed=distance<=.001))
            for other in fixed:
                checks+=1;overlap=bvh.overlap(tree(other))
                if overlap:collisions.append(dict(frame=frame,a=blade.name,b=other.name,pairs=len(overlap)))
        for i,blade in enumerate(blades):
            for other in blades[i+1:]:
                checks+=1;overlap=tree(blade).overlap(tree(other))
                if overlap:collisions.append(dict(frame=frame,a=blade.name,b=other.name,pairs=len(overlap)))
        if frame in (1,193):loop[frame]={o.name:[float(c) for row in o.matrix_world for c in row] for o in blades}
    loop_error=max(abs(a-b) for name,values in loop[1].items() for a,b in zip(values,loop[193][name]))
    stats=mesh_stats(s);bores=port_probe(s,ports,max_radius=.235);errors=[]
    if any(not c['passed'] for c in contacts):errors.append('assembly contacts')
    if hits:errors.append('process route core blocked')
    if any(not t['passed'] for t in transitions):errors.append('twisted or deformed transition geometry')
    if collisions:errors.append('fan collision')
    if receipt.get('fan_blade_count') and (len(blades)!=receipt['fan_blade_count'] or not hub or any(not r['passed'] for r in blade_contacts)):errors.append('fan blade roots not attached to hub')
    if loop_error>1e-4:errors.append('working loop closure')
    if not bores['passed']:errors.append('external mouths')
    if stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('mesh validity')
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),artifact_sha256=sha(args.glb or source),runtime_artifact=bool(args.glb),contacts=contacts,core_rays=rays,core_hits=hits,transitions=transitions,
        fan_surface_pair_checks=checks,fan_collisions=collisions,fan_blade_contacts=blade_contacts,fan_loop_error=loop_error,external_bores=bores,mesh_stats=stats,bounds=bounds(meshes),
        scope='Actual evaluated contacts, five core paths per curved process segment into drilled vessel and 17 fan poses. This is a targeted geometry audit, not structural/pressure certification or native seating proof.')
    (out/'mechanical-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('CRUCIBLE_MECHANICS',not errors,errors,'contact_failures',sum(not c['passed'] for c in contacts),'core_hits',len(hits),'fan_collisions',len(collisions),flush=True)


if __name__=='__main__':main()
