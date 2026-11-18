"""Independent packed source and actual GLB inspection, four facings and clay."""
from pathlib import Path
R=Path(__file__).resolve().parents[3];p=R/'tools/art/conclave/inspect.py';src=p.read_text().replace("R/'art/source-to-3d/conclave-center/v01'","R/'art/source-to-3d/primitive-battery-bank/v01'").replace("STEM='conclave-center-'+O.name.split('-')[0]","STEM='primitive-battery-bank-v01'").replace('CONCLAVE_INSPECTION','BATTERY_BANK_INSPECTION').replace("clay.diffuse_color=(.35,.35,.35,1);","clay.use_nodes=True;clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.3,.3,.3,1);")
exec(compile(src,str(p),'exec'))
