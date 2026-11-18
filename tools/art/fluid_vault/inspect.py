"""Independent source/export inspection at the measured three-tile pipe extent."""
from pathlib import Path
R=Path(__file__).resolve().parents[3];p=R/'tools/art/conclave/inspect.py';src=p.read_text().replace("R/'art/source-to-3d/conclave-center/v01'","R/'art/source-to-3d/pressurized-fluid-vault/v01'").replace("STEM='conclave-center-'+O.name.split('-')[0]","STEM='pressurized-fluid-vault-v01'").replace('CONCLAVE_INSPECTION','FLUID_VAULT_INSPECTION').replace("clay.diffuse_color=(.35,.35,.35,1);","clay.use_nodes=True;clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.3,.3,.3,1);")
src=src.replace('lo[0]>=-1 and hi[0]<=1 and lo[1]>=-1 and hi[1]<=1','lo[0]>=-1.56 and hi[0]<=1.56 and lo[1]>=-1.56 and hi[1]<=1.56')
exec(compile(src,str(p),'exec'))
