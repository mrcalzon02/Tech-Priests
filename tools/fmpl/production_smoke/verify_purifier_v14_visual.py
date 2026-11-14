"""Run the existing strict Cycles isolation gates on the corrected V14 panel."""
from pathlib import Path
import json
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_central_visual as v

old_named=v.named
def named(scene,needle):
    if needle=='angled CRT live green readout bar':
        needle='TP_MH7_V14 | console live green bar'
    return old_named(scene,needle)

v.named=named
v.ROI['screen']=(305,290,420,372)
v.main()
out=Path(sys.argv[sys.argv.index('--out')+1])/'central-console-visual-proof.json'
report=json.loads(out.read_text())
report['schema']='fmpl.purifier-v14.render-isolation.v1'
report['console_roi_authority']='actual raised full-casting V14 console, source camera 512px'
out.write_text(json.dumps(report,indent=2)+'\n')
