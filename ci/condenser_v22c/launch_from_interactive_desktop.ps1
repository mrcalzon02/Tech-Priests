# Source-locked V22C Martian condenser graphical client capture.
# Execute ONLY in a logged-on Windows desktop, NEVER Windows service Session 0.
# Do not modify game installs, actual saves, Steam data or the runner service.
[CmdletBinding()]
param(
  [string]$FactorioExe = '',
  [string]$OutputDirectory = '',
  [int]$MaxSeconds = 360
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
  throw 'Real client capture requires an interactive Windows desktop'
}
$session = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
if ($session -eq 0) {
  throw 'INTERACTIVE_DESKTOP_REQUIRED: this is Windows Session 0 (service). Launch PowerShell from a logged-on desktop before running Factorio GUI screenshots.'
}
Write-Host "TP_CONDENSER_V22C_INTERACTIVE_SESSION $session"
if (@(Get-Process -Name factorio -ErrorAction SilentlyContinue).Count -ne 0) {
  throw 'Factorio is already running. Stop this capture attempt rather than interrupt a user game.'
}
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $PSScriptRoot 'visual_capture.py'
$proof = Join-Path $root 'art/source-to-3d/condenser-v21/captures/v22c/Condenser_V22C_Four_Way_Integration_Proof.png'
$manifest = Join-Path $root 'tech-priests_src/graphics/entity/atmospheric-water-condenser-v22c/atlas_manifest.json'
$graphics = Join-Path $root 'tech-priests_src/graphics/entity/atmospheric-water-condenser-v22c/active-north-hr-00.png'
foreach ($file in @($script,$proof,$manifest,$graphics)) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Incomplete checked-out Tech-Priests V22C graphical source: $file"
  }
}
$candidates=@(
  'C:\Program Files\Python312\python.exe',
  'C:\Program Files\Python311\python.exe',
  'C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe'
)
$cmd=Get-Command python.exe -ErrorAction SilentlyContinue
if ($cmd) { $candidates+= [string]$cmd.Source }
$python=$null
foreach ($candidate in @($candidates | Select-Object -Unique)) {
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
  $v=((& $candidate -c 'import sys;print(sys.version_info.major,sys.version_info.minor)' 2>&1) | Out-String).Trim()
  if ($LASTEXITCODE -eq 0 -and $v -match '^3\s+1[0-9]$') {
    $python=$candidate
    break
  }
}
if (-not $python) { throw 'Python 3.10+ is required for the real screenshot verifier.' }
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$work=Join-Path $env:TEMP ("condenser-v22c-gui-$stamp")
if (Test-Path -LiteralPath $work) { throw "Refusing to overwrite $work" }
New-Item -ItemType Directory -Path $work | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory=Join-Path $root "models/island-survival/solar-boiler/condenser_v22c/visual-client-$stamp"
}
$out=[IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $out) { throw "Refusing to overwrite screenshot evidence: $out" }
# Keep any missing Pillow dependency in disposable scratch, never system Python.
$priorErrorAction=$ErrorActionPreference
$ErrorActionPreference='Continue'
try {
  & $python -c 'from PIL import Image; print(Image.__version__)' 2>$null
  $pillowExit=$LASTEXITCODE
} finally { $ErrorActionPreference=$priorErrorAction }
if ($pillowExit -ne 0) {
  $deps=Join-Path $work 'python-deps'
  New-Item -ItemType Directory -Path $deps | Out-Null
  & $python -m pip install --disable-pip-version-check --no-input --only-binary=:all: --target $deps 'Pillow==11.3.0'
  if ($LASTEXITCODE -ne 0) { throw 'Isolated Pillow dependency installation failed' }
  $env:PYTHONPATH=$deps
}
$args=@($script,'--output',$out,'--working',(Join-Path $work 'isolated-runtime'),'--max-seconds',[string]$MaxSeconds)
if ($FactorioExe) { $args+=@('--client',$FactorioExe) }
Write-Host 'Launching the REAL graphical Factorio 2.1 Windows client in this interactive session.'
Write-Host 'The user game installation, saves and registered mods are read-only.'
Write-Host "Screenshots will be saved under: $out"
& $python @args
if ($LASTEXITCODE -ne 0) {
  throw "Real Factorio screenshot capture failed. Inspect $out\client-capture-error.json and $work\isolated-runtime\graphical-factorio.log. No visual approval recorded."
}
$qa=Join-Path $out 'client-capture-qa.json'
if (-not (Test-Path -LiteralPath $qa -PathType Leaf)) { throw 'Missing native screenshot QA receipt' }
$receipt=Get-Content -LiteralPath $qa -Raw | ConvertFrom-Json
if (-not $receipt.passed -or $receipt.factorio_headless -or
    $receipt.screen_capture_count -ne 16 -or
    $receipt.native_connected_pipes -ne 8 -or
    $receipt.fueled_active_machines -ne 4) {
  throw 'Native Factorio screenshots did not pass required source/pipe/animation proof gates'
}
Write-Host 'TP_CONDENSER_V22C_ACTUAL_GUI_SCREENSHOTS_VERIFIED count=16'
Write-Host "Four-way genuine game contact sheet: $(Join-Path $out 'condenser-v22c-real-game-four-directions.png')"
Write-Host "Source comparison: $(Join-Path $out 'client-vs-approved-v22c-blender.png')"
Write-Host 'Review native pipe mouth alignment and animated intake; do not call visual approval automatic.'
# Package only the independently verified genuine Factorio screenshot output.
# Keep a distinct non-overwriting ZIP for easy review/upload from the desktop.
$gallery=Join-Path $out 'factorio-client-pipes-all-four.png'
$comparison=Join-Path $out 'client-vs-approved-v8.png'
foreach($file in @($gallery,$comparison)){
  if(-not(Test-Path -LiteralPath $file -PathType Leaf)){
    throw ('Missing expected real client visual proof: '+$file)
  }
}
$bundle=$out+'.zip'
if(Test-Path -LiteralPath $bundle){
  throw ('Refusing to overwrite existing screenshot ZIP: '+$bundle)
}
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $bundle -CompressionLevel Optimal
if(-not(Test-Path -LiteralPath $bundle -PathType Leaf) -or
   (Get-Item -LiteralPath $bundle).Length -lt 4096){
  throw 'Screenshot evidence ZIP was not created successfully'
}
Write-Host ('Genuine Factorio screenshot evidence ZIP: '+$bundle)
try {
  Start-Process -FilePath $gallery -ErrorAction Stop | Out-Null
  Write-Host 'Opened actual in-game comparison sheet in the desktop image viewer.'
} catch {
  Write-Warning ('Open the in-game visual contact sheet manually: '+$gallery)
}

