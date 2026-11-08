import json,os
from pathlib import Path
O=Path(__file__).resolve().parent
report={'status':'VERIFIED_CAPTURE_PUBLISHED','source_commit':os.environ['GITHUB_SHA'],'run_url':os.environ['RUN_URL'],'release_url':'https://github.com/'+os.environ['GITHUB_REPOSITORY']+'/releases/tag/lobber-capture-'+os.environ['GITHUB_RUN_ID'],'delivery':json.loads(Path('delivery/delivery_manifest.json').read_text())}
(O/'DELIVERY.json').write_text(json.dumps(report,indent=2))
