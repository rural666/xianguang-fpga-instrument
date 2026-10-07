param([string]$Project=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$taskTables=@(
    @{name='sine2048.hex';count=2048;sha='391186737F61BAEE61BE6D6084999D5A43005D47ED173B51F95416D6B0C38C14'},
    @{name='ima_steps.hex';count=89;sha='50F3D4EE0D9CBA27CDE200B10CA7D85D05AA9E3D0A1888660496047066E0463D'}
)
foreach($taskTable in $taskTables){
    $taskPath=Join-Path $Project ('rtl\'+$taskTable.name)
    if(!(Test-Path -LiteralPath $taskPath -PathType Leaf)){throw ('Required audio ROM missing: '+$taskTable.name)}
    $taskWords=@(Get-Content -LiteralPath $taskPath)
    if($taskWords.Count -ne $taskTable.count -or @($taskWords | Where-Object {$_ -notmatch '^[0-9a-fA-F]{4}$'}).Count){throw ('Invalid audio ROM words: '+$taskTable.name)}
    if((Get-FileHash -LiteralPath $taskPath).Hash -ne $taskTable.sha){throw ('Audio ROM differs from validated soft-piano source: '+$taskTable.name)}
}
Write-Output 'PASS required sine and ADPCM ROM files, word counts and SHA256'
