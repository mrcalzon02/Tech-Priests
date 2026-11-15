"""Promote only hash-matched, clean-appended source-backed part revisions."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import bpy

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--harvest',required=True);ap.add_argument('--registry',required=True)
    ap.add_argument('--expected-registry-sha',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);harvest=Path(args.harvest).resolve();path=Path(args.registry).resolve()
    if sha(path)!=args.expected_registry_sha:raise RuntimeError('Registry changed; reconcile instead of overwrite')
    registry=json.loads(path.read_text());entries=[]
    if not (path.parent/'.gitattributes').exists():(path.parent/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for folder in ('cogitator-console','fluid-mouth'):
        source=harvest/folder;record=json.loads((source/'part.json').read_text());qa=json.loads((source/'verification.json').read_text())
        if not qa['passed'] or sha(source/'part.blend')!=qa['source_sha256'] or sha(source/'thumbnail.png')!=qa['thumbnail_sha256']:
            raise RuntimeError('Unverified part cannot be promoted')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(source/'part.blend'),link=False) as (fr,to):to.collections=[record['collection']]
        materials={m for ob in to.collections[0].all_objects for m in ob.data.materials if m}
        material_records=[]
        for mat in sorted(materials,key=lambda m:m.name):
            images={n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image} if mat.use_nodes else set()
            material_records.append(dict(id=mat.name,packed_maps=[dict(name=i.name,size=list(i.size),
                sha256=hashlib.sha256(i.packed_file.data).hexdigest() if i.packed_file else None) for i in sorted(images,key=lambda i:i.name)]))
        dest=path.parent/'components'/folder/'v1'
        if dest.exists():raise FileExistsError('Never overwrite a registered revision')
        shutil.copytree(source,dest)
        record.update(status='verified',verification_scope='clean append, actual render, bounds/packed maps; model-space geometry only',
            source_blend=str((dest/'part.blend').relative_to(path.parent)).replace('\\','/'),
            thumbnail=str((dest/'thumbnail.png').relative_to(path.parent)).replace('\\','/'),
            verification=str((dest/'verification.json').relative_to(path.parent)).replace('\\','/'),
            dimensions_tiles=qa['dimensions'],pivot=[0,0,0],materials=material_records,
            validation='fresh append and actual thumbnail passed; fluid mouth inner-core rays clear where applicable')
        component=dict(record);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json')
        (dest/'part.json').write_text(json.dumps(component,indent=2)+'\n')
        entries.append(record)
    if sha(path)!=args.expected_registry_sha:raise RuntimeError('Registry changed during harvesting')
    existing={(r['part_id'],r['revision']) for r in registry['parts']}
    if any((r['part_id'],r['revision']) in existing for r in entries):raise RuntimeError('Duplicate registered revision')
    registry['parts'].extend(entries)
    registry['instances_by_machine']['water-purifier']=[dict(part_id=r['part_id'],revision='v1',transform=r['source_instance_frame']) for r in entries]
    registry['previous_registry_sha256']=args.expected_registry_sha
    tmp=path.with_suffix('.json.tmp');tmp.write_text(json.dumps(registry,indent=2)+'\n');tmp.replace(path)
    print('REGISTERED_REAL_PARTS',len(entries),sha(path),flush=True)

if __name__=='__main__':main()
