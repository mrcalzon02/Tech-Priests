# Stage 5 Smoke-Test Packaging Checklist

This checklist gates the Stage 5 movement repair batch before any version bump.

## Scope covered

Stage 5 currently covers:

- Movement request failure reporting for movement-driven executors.
- Proximity/range gates before work, deposit, placement, consecration, repair, and logistics actions.
- Direct acquisition travel, deposit-blocked, and return-to-station failure accounting.
- Machine logistics stale known-source fetch timeout handling.
- Separate Void Priest movement authority through `void_movement_authority_0630.lua`.
- Runtime installation of Void movement through `movement_enforcement_0566.lua`.

## Required local checks before package

From the repository root, run:

```bash
python tools/check_stage5_smoke_bundle.py
```

The bundle runs:

```text
tools/check_stage5_movement_failure_batch.py
tools/check_stage5_proximity_gates.py
tools/check_void_movement_authority_0630.py
```

Do not package or bump `tech-priests_src/info.json` if any checker fails.

## Smoke package creation

Only after the smoke bundle passes, create a local smoke package from the repository root.

Recommended PowerShell shape:

```powershell
$ModName = "tech-priests"
$Version = (Get-Content tech-priests_src/info.json | ConvertFrom-Json).version
$Out = "dist/${ModName}_${Version}-stage5-smoke.zip"
New-Item -ItemType Directory -Force dist | Out-Null
if (Test-Path "dist/${ModName}") { Remove-Item -Recurse -Force "dist/${ModName}" }
Copy-Item -Recurse tech-priests_src "dist/${ModName}"
Compress-Archive -Force "dist/${ModName}" $Out
Write-Host "Created $Out"
```

Recommended Bash shape:

```bash
mkdir -p dist
version=$(python - <<'PY'
import json
print(json.load(open('tech-priests_src/info.json', encoding='utf-8'))['version'])
PY
)
rm -rf dist/tech-priests
cp -R tech-priests_src dist/tech-priests
(cd dist && zip -qr "tech-priests_${version}-stage5-smoke.zip" tech-priests)
echo "Created dist/tech-priests_${version}-stage5-smoke.zip"
```

## Factorio smoke load

Install the smoke ZIP into the local Factorio mods folder, then start Factorio with a fresh test save or a copied test save.

Minimum smoke observations:

- Mod reaches the main menu without a Lua load error.
- Existing ground Tech-Priests still issue ordinary ground movement through the normal movement stack.
- Movement-failure diagnostics do not spam continuously during idle operation.
- `/tp-runtime-report` still opens and reports runtime services.
- `/tp-void-movement-0630` exists and reports enabled status.
- Void Priest movement requests, where available, report `void-requested`, `void-jetpack-transit`, and `void-arrived` instead of ground pathing states.

## Do not bump yet if

- Any checker fails.
- Factorio reports a Lua load error.
- Void movement steals ordinary ground-priest movement.
- A movement-driven executor reports normal work after a failed movement request.
- A task performs work/deposit/placement before reaching its range gate.

## Version bump rule

Only after the smoke package passes a Factorio load test should `tech-priests_src/info.json` be bumped and the description updated for the Stage 5 movement/void authority batch.
