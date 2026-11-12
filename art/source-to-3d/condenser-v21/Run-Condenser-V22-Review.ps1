# Run the approved-source condenser V22 motion review on the user's Windows Blender host.
# No GitHub workflow, production art mutation, force-push, or unverified source replacement.
# From PowerShell, run from a current Tech-Priests main checkout:
#   & './art/source-to-3d/condenser-v21/Run-Condenser-V22-Review.ps1'
[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
    [string]$OutputRoot = 'D:\AI-Relocation\Tech-Priests-Reviews'
)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = (Resolve-Path (Join-Path $ScriptDir '..\..\..')).Path
$Runner = Join-Path $ScriptDir 'run_condenser_v22_review.py'
if (-not (Test-Path -LiteralPath $Runner -PathType Leaf)) { throw "Missing committed V22 runner: $Runner" }
if (-not (Test-Path -LiteralPath $Blender -PathType Leaf)) { throw "Blender is missing: $Blender" }
if ($SourceRoot -and -not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { throw "Source root is missing: $SourceRoot" }
$Python = Get-Command py -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $Python) { throw 'Python is missing. Install Python 3 and Pillow to run this review.' }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$Dest = Join-Path $OutputRoot ("Condenser-V22-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Write-Host "Reviewing the exact source-locked condenser V21 -> V22 animation"
Write-Host ("Source: " + $(if ($SourceRoot) { $SourceRoot } else { "Git-tracked SHA256 source archive" }))
Write-Host "Blender: $Blender"
Write-Host "Fresh output: $Dest"
Push-Location $Repo
try {
    if ($SourceRoot) {
        & $Python.Source $Runner --search-root $SourceRoot --blender $Blender --out $Dest
    } else {
        & $Python.Source $Runner --repo-source --blender $Blender --out $Dest
    }
    if ($LASTEXITCODE -ne 0) { throw "Native Blender V22 review failed (exit $LASTEXITCODE); no production sprites changed." }
} finally {
    Pop-Location
}
$Bundle = Join-Path $Dest 'Condenser_V22_Native_Review_Bundle.zip'
if (-not (Test-Path -LiteralPath $Bundle -PathType Leaf)) { throw "No verified review archive: $Bundle" }
Write-Host 'Real Blender review archive and SHA-256:'
Get-FileHash -Algorithm SHA256 -LiteralPath $Bundle | Format-List
Write-Host "Review contact sheet, isolation proof and GIF are in: $Dest"
Write-Host 'Not owner-approved. Factorio sprites are unchanged.'
