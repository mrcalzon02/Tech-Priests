"""Check rigid mouths, unchanged accepted body and four actual hollow poses."""
import argparse,json,math,sys
from pathlib import Path
import bpy
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from purifier_native_fittings import PurifierNativeFittings
from finish_fabricator_v03 import mesh_digest
from mathutils.bvhtree import BVHTree
from verify_purifier_v14 import gap
from mh7_machine_scene import sha


def scene_tree():
    vertices=[];faces=[];names=[]
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH' or obj.hide_render:continue
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh();offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in mesh.vertices);mesh.calc_loop_triangles()
        for triangle in mesh.loop_triangles:faces.append(tuple(offset+i for i in triangle.vertices));names.append(obj.name)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices,faces,all_triangles=True),names


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve actual native fitting evidence')
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    original={o.name:mesh_digest(o) for o in s.objects if o.type=='MESH'};camera=s.camera.matrix_world.copy();matrices={o.name:o.matrix_world.copy() for o in s.objects if o.type=='MESH'}
    pivot=bpy.data.objects.new('Independent fitting rotation pivot',None);s.collection.objects.link(pivot);roots=set()
    for o in list(s.objects):
        if o.type!='MESH':continue
        root=o
        while root.parent:root=root.parent
        roots.add(root)
    for root in roots:root.parent=pivot;root.matrix_parent_inverse=Matrix.Identity(4)
    fitting=PurifierNativeFittings(s);mouths={o.name for group in fitting.groups.values() for o in group};rows=[]
    for angle in (0,90,180,270):
        rotation=Matrix.Rotation(math.radians(angle),4,'Z');pivot.rotation_euler.z=math.radians(angle);changes=fitting.apply(angle);bpy.context.view_layer.update();tree,names=scene_tree();blocked=[];rays=0;contacts=[]
        body_error=max(abs(a-b) for name,old in matrices.items() if name not in mouths for a,b in zip([v for row in s.objects[name].matrix_world for v in row],[v for row in rotation@old for v in row]))
        mouth_errors=[]
        for entry in changes:
            expected_translation=Matrix.Translation(Vector(entry['rigid_world_offset']))
            for obj in fitting.groups[entry['role']]:
                expected=expected_translation@rotation@matrices[obj.name]
                error=max(abs(a-b) for actual_row,expected_row in zip(obj.matrix_world,expected) for a,b in zip(actual_row,expected_row))
                mouth_errors.append(dict(object=obj.name,error=error))
        for role,sign in [('raw-water-in',-1),('purified-water-out',1)]:
            entry=next(r for r in changes if r['role']==role);center=Vector(entry['mouth_center']);end=(rotation@Vector((sign*1.215,0,.36,1))).xyz;direction=(end-center).normalized();across=(rotation.to_3x3()@Vector((0,1,0)));up=Vector((0,0,1))
            for offset in [Vector()]+[.20*(math.cos(i*math.tau/8)*across+math.sin(i*math.tau/8)*up) for i in range(8)]:
                rays+=1;hit,_,index,_=tree.ray_cast(center+offset+direction*.001,direction,(end-center).length-.002)
                if hit is not None:blocked.append(dict(role=role,object=names[index],at=list(hit)))
            ext=fitting.extensions[role][0];throat=next(o for o in fitting.groups[role] if 'reusable machine throat' in o.name)
            if not ext.hide_render:contacts.append(dict(role=role,gap=gap(ext,throat)))
        preserved=all(mesh_digest(s.objects[name])==digest for name,digest in original.items());camera_error=max(abs(a-b) for arow,brow in zip(camera,s.camera.matrix_world) for a,b in zip(arow,brow))
        passed=preserved and body_error<1e-6 and all(r['error']<1e-6 for r in mouth_errors) and camera_error==0 and not blocked and all(r['gap']<.015 for r in contacts)
        rows.append(dict(angle=angle,passed=passed,accepted_meshes_unchanged=preserved,body_pose_error=body_error,rigid_mouth_pose_errors=mouth_errors,camera_error=camera_error,core_rays=rays,obstructions=blocked,mouth_extension_contacts=contacts,changes=changes))
    out.write_text(json.dumps(dict(passed=all(r['passed'] for r in rows),source_sha256=sha(source),preserved_meshes=len(original),core_rays=sum(r['core_rays'] for r in rows),poses=rows,scope='Original accepted meshes, body poses and camera remain unchanged. Twenty mouth meshes move rigidly; only two new constant-bore sleeves parameterize axial extension. Four poses and bounded hollow-core rays are geometric evidence; actual native pipe seating remains a separate review.'),indent=2)+'\n');print('PURIFIER_NATIVE_FITTINGS',all(r['passed'] for r in rows),[(r['angle'],r['body_pose_error'],r['obstructions']) for r in rows],flush=True)


if __name__=='__main__':main()
