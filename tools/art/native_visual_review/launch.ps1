param([Parameter(Mandatory=$true)][string]$ReviewRoot, [switch]$LowVram)
$reviewRoot=(Resolve-Path -LiteralPath $ReviewRoot).Path
if(-not (Test-Path -LiteralPath (Join-Path $reviewRoot 'mods/model-visual-review_0.1.0/info.json'))){throw 'Expected an isolated model-visual-review profile'}
if(-not $LowVram){
  $configPath=Join-Path $reviewRoot 'config.ini'
  $configText=[System.IO.File]::ReadAllText($configPath)
  if($configText -match '(?m)^optimize-for-low-vram='){
    $configText=[regex]::Replace($configText,'(?m)^optimize-for-low-vram=.*$','optimize-for-low-vram=false')
  }else{$configText=$configText.Replace('[graphics]',"[graphics]`noptimize-for-low-vram=false")}
  $configText=[regex]::Replace($configText,'(?m)^graphics-quality=.*$','graphics-quality=high')
  [System.IO.File]::WriteAllText($configPath,$configText)
}
$reviewClients=Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains($reviewRoot+'\config.ini')}
foreach($reviewClient in $reviewClients){Stop-Process -Id $reviewClient.ProcessId}
$steamArgs=@('-applaunch','427520','--config',('"'+$reviewRoot+'\config.ini"'),'--mod-directory',('"'+$reviewRoot+'\mods"'),'--load-scenario','model-visual-review/model-placement','--disable-audio','--window-size','1280x900')
# Low-memory mode is opt-in and cannot establish final visual acceptance.
if($LowVram){$steamArgs+='--low-vram'}
Start-Process -FilePath 'C:/Program Files (x86)/Steam/steam.exe' -ArgumentList $steamArgs -WindowStyle Hidden
