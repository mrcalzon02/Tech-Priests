"""Extract two actual source-backed assemblies from the accepted purifier."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import math
import bpy
from mathutils import Matrix,Vector

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Keep part revisions immutable')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(src));bpy.context.scene.frame_set(25)
    visible=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render]
    pivot=Vector((1.12,-1.18,0))
    console_frame=(Matrix.Translation((.12,0,.775)) @ Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(12),4,'Z') @ Matrix.Translation(-pivot) @ Matrix.Translation((.805,-1.18,.90)))
    console=[o for o in visible if o.name.startswith(('TP_MH7_V14 | console /','TP_MH7_V14 | console cast side extension',
               'TP_MH7_V14 | CRT ','TP_MH7_V14 | console seated button boss','TP_MH7_V14 | console live green bar'))]
    mouth=[o for o in visible if 'FMPL_PROCESS | purified-water-out /' in o.name and
              any(t in o.name for t in ('reusable machine collar','reusable machine throat','actual flange bolt'))]
    if len(console)!=20 or len(mouth)!=10:raise RuntimeError('Unexpected donor census: '+str((len(console),len(mouth))))
    specs=[('cogitator-console','tp.mh7.cogitator-console',console,console_frame,
             {'mount_base':dict(position=[0,0,-.285],normal=[0,0,-1],connector_class='mechanical case mount'),
              'front_panel':dict(position=[0,-.167,0],normal=[0,-1,0],connector_class='service control face'),
              'rear_gland':dict(position=[-.005,.135,.20],normal=[0,1,0],connector_class='electrical; no gameplay wire socket')}),
           ('fluid-mouth','tp.mh7.factorio-fluid-mouth',mouth,Matrix.Translation((1.5,0,.36)),
             {'mating_plane':dict(position=[0,0,0],normal=[1,0,0],connector_class='fluid .49 bore / .68 flange; native cell unassigned'),
              'throat_back':dict(position=[-.30,0,0],normal=[-1,0,0],connector_class='machine-side receiving throat')})]
    for folder,part_id,objects,frame,anchors in specs:
        dest=out/folder;dest.mkdir();collection=bpy.data.collections.new('TP LIB | '+folder+' | v1')
        names=[]
        for old in objects:
            ob=old.copy();ob.data=old.data.copy();ob.parent=None
            ob.name=part_id+' | '+old.name;collection.objects.link(ob)
            ob.matrix_world=frame.inverted() @ old.matrix_world
            ob['donor_object']=old.name;ob['part_id']=part_id;ob['part_revision']='v1';names.append(ob.name)
        path=dest/'part.blend'
        bpy.data.libraries.write(str(path),{collection},fake_user=True,compress=True)
        record=dict(part_id=part_id,revision='v1',family=folder,status='candidate',
            source_blend='part.blend',source_sha256=sha(path),collection=collection.name,mesh_count=len(objects),
            donor=dict(path=str(src),sha256=sha(src),machine='water-purifier',revision='V16 owner shape accepted'),
            license='user-authored Tech-Priests geometry and FMPL material provenance; no third-party mesh donor',
            axes='+X right, +Y back, +Z up; fluid mouth outward +X',units='Factorio tile',
            anchors=anchors,native_port_cells=None,source_instance_frame=[list(r) for r in frame],objects=names,
            surface_plan='retained source-authored placement and packed FMPL PBR; copy materials per consumer',
            consumers=[dict(machine='water-purifier',source_sha256=sha(src),transform=[list(r) for r in frame])],
            validation='fresh append/thumbnail pending')
        (dest/'part.json').write_text(json.dumps(record,indent=2)+'\n')
        print('HARVESTED',part_id,len(objects),flush=True)

if __name__=='__main__':main()
