#!/usr/bin/env bash
set -euo pipefail
# One authorized existing Tech-Priests publishing workflow; main only.
# No force-push, extra workflow, prototype bypass or generated 2D substitute.
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
DIR=tech-priests_src/graphics/entity/emergency-miner-v25
required=(activity-hr.png activity.png idle-hr.png idle.png icon-64.png icon-128.png)
complete=true
for f in "${required[@]}"; do [[ -s "$DIR/$f" ]] || complete=false; done
if [[ "$complete" == true ]] && grep -q 'require("prototypes.generated_graphics.emergency-miner-v25")' tech-priests_src/data-final-fixes.lua; then
  echo 'EMERGENCY_MINER_V25_ALREADY_IN_MAIN: skip re-render; original sprite preserved'
  exit 0
fi
for f in "${required[@]}"; do [[ ! -e "$DIR/$f" ]] || { echo "PARTIAL_V25_ASSETS $f"; exit 1; }; done
python3 -m pip install --disable-pip-version-check --break-system-packages 'Pillow>=10,<13'
sudo apt-get update -qq -o Acquire::Retries=3
sudo apt-get install -y -qq libxi6 libxfixes3 libxrender1 libgl1 libegl1 libxkbcommon0
mkdir -p .tools
curl -fL --retry 3 --retry-delay 8 --connect-timeout 25 --max-time 600 \
  https://download.blender.org/release/Blender5.2/blender-5.2.3-linux-x64.tar.xz \
  -o .tools/blender-5.2.3-linux-x64.tar.xz
tar -xJf .tools/blender-5.2.3-linux-x64.tar.xz -C .tools
BLENDER="$ROOT/.tools/blender-5.2.3-linux-x64/blender"
"$BLENDER" --version | head -n 2
OUT="$RUNNER_TEMP/emergency-miner-v25-release"
mkdir -p "$OUT"
SCRIPT=art/source-to-3d/emergency-miner
"$BLENDER" -b --factory-startup --threads 4 --python-exit-code 1 \
  --python "$SCRIPT/animate_preview.py" -- --out "$OUT" --quick-review --variant-a-only
"$BLENDER" -b "$OUT/miner_motion_A.blend" --threads 4 --python-exit-code 1 \
  --python "$SCRIPT/verify_animation.py" -- --out "$OUT" --variant A
mkdir -p "$OUT/four_orientations/A"
"$BLENDER" -b "$OUT/miner_motion_A.blend" --threads 4 --python-exit-code 1 \
  --python "$SCRIPT/render_four_orientations.py" -- \
  --out "$OUT/four_orientations/A" --variant A
"$BLENDER" -b "$OUT/four_orientations/A/V25_four_orientation_preview_A.blend" \
  --threads 4 --python-exit-code 1 --python "$SCRIPT/verify_four_orientations.py" \
  -- --out "$OUT/four_orientations/A" --variant A
python3 "$SCRIPT/pack_factorio_v25.py" \
  --source "$OUT/four_orientations/A" --mod tech-priests_src --manifest "$SCRIPT"
python3 - <<'PY'
from pathlib import Path
import json
path=Path('tech-priests_src/data-final-fixes.lua')
s=path.read_text(encoding='utf8')
anchor='require("prototypes.emergency_miner_no_fuel_0641")'
addition='require("prototypes.generated_graphics.emergency-miner-v25")'
assert s.count(anchor)==1 and addition not in s, 'Unreconciled prototype registration'
path.write_text(s.replace(anchor,anchor+'\n-- Owner-approved FMPL V25 four-way art\n'+addition),encoding='utf8')
info=Path('tech-priests_src/info.json')
obj=json.loads(info.read_text(encoding='utf8'))
assert obj['name']=='tech-priests' and obj['version']=='0.1.678', 'Unreconciled version; preserve newer release'
obj['version']='0.1.679'
info.write_text(json.dumps(obj,indent=2)+'\n',encoding='utf8')
PY
python3 - <<'PY'
from pathlib import Path
import json
from PIL import Image
base=Path('tech-priests_src/graphics/entity/emergency-miner-v25')
data=json.loads(Path('art/source-to-3d/emergency-miner/emergency-miner-v25-atlas-manifest.json').read_text())
assert data['approved_revision']=='V25' and data['directional_frame_count']==16
for name,receipt in data['emitted'].items():
    with Image.open(base/name) as image: image.verify()
    assert (base/name).stat().st_size==receipt['bytes']
print('EMERGENCY_MINER_V25_ATLAS_AND_PROTOTYPE_GATES_PASS')
PY
git add "$DIR" tech-priests_src/data-final-fixes.lua tech-priests_src/info.json \
  "$SCRIPT/emergency-miner-v25-atlas-manifest.json"
git config user.name 'Tech Priests art integration'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git commit -m 'feat: integrate approved V25 miner sprites into Factorio 2.1 [skip ci]'
pushed=false
for attempt in 1 2 3; do
  git fetch origin main
  git rebase origin/main
  if git push origin HEAD:main; then pushed=true; break; fi
  sleep "$((attempt*4))"
done
[[ "$pushed" == true ]] || { echo 'V25_COMMIT_PUSH_FAILED'; exit 1; }
sha=$(git rev-parse HEAD)
echo "EFFECTIVE_SOURCE_SHA=$sha" >> "$GITHUB_ENV"
echo "EMERGENCY_MINER_V25_PUSH_VERIFIED $sha"
