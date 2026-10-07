param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskBaseline=Get-Content -LiteralPath (Join-Path $taskRoot 'docs/baseline-v2.1.2.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$taskCount=0
foreach($taskEntry in $taskBaseline.protected_files){
    $taskPath=Join-Path $taskRoot $taskEntry.path
    if(!(Test-Path -LiteralPath $taskPath -PathType Leaf)){throw ('Missing baseline file: '+$taskEntry.path)}
    if((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash -ne $taskEntry.sha256){throw ('Baseline file changed: '+$taskEntry.path)}
    $taskCount++
}
$taskManifest=Get-Content -LiteralPath (Join-Path $taskRoot 'fpga_source/firmware/manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if((Get-FileHash -LiteralPath (Join-Path $taskRoot 'fpga_source/firmware/control.fs')).Hash -ne $taskManifest.sha256){throw 'Bundled firmware does not match manifest'}
& (Join-Path $taskRoot 'fpga_source/scripts/validate_roms.ps1') -Project (Join-Path $taskRoot 'fpga_source')
Write-Output ('PASS v2.1.2 baseline: '+$taskCount+' source/asset/constraint/firmware files unchanged')
