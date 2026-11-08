param([Parameter(Mandatory=$true)][string]$ReviewRoot)
$reviewRoot=(Resolve-Path -LiteralPath $ReviewRoot).Path
$reviewClients=Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains($reviewRoot+'\config.ini')}
foreach($reviewClient in $reviewClients){Stop-Process -Id $reviewClient.ProcessId}
$steamArgs=@('-applaunch','427520','--config',('"'+$reviewRoot+'\config.ini"'),'--mod-directory',('"'+$reviewRoot+'\mods"'),'--load-scenario','model-visual-review/model-placement','--disable-audio','--low-vram','--window-size','1280x900')
Start-Process -FilePath 'C:/Program Files (x86)/Steam/steam.exe' -ArgumentList $steamArgs -WindowStyle Hidden
