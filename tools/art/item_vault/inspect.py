"""Reopen source and independently import/render the actual Item Vault GLB."""
from pathlib import Path
R=Path(__file__).resolve().parents[3];p=R/'tools/art/conclave/inspect.py';src=p.read_text()
src=src.replace("R/'art/source-to-3d/conclave-center/v01'","R/'art/source-to-3d/item-vault/v01'").replace("STEM='conclave-center-'+O.name.split('-')[0]","STEM='item-vault-v01'").replace('CONCLAVE_INSPECTION','ITEM_VAULT_INSPECTION')
src=src.replace("clay.diffuse_color=(.35,.35,.35,1);","clay.use_nodes=True;clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.3,.3,.3,1);")
exec(compile(src,str(p),'exec'))
