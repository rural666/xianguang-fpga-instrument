param()
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$taskPrefix=$taskRoot+[IO.Path]::DirectorySeparatorChar
$taskList=Join-Path $taskRoot 'SHA256SUMS.txt'
$taskCount=0
foreach($taskLine in Get-Content -LiteralPath $taskList){
    if(!$taskLine.Trim()){continue}
    if($taskLine -notmatch '^([0-9A-Fa-f]{64})  (.+)$'){throw 'Invalid checksum line'}
    $taskExpected=$Matches[1];$taskRelative=$Matches[2]
    $taskPath=[IO.Path]::GetFullPath((Join-Path $taskRoot $taskRelative))
    if(!$taskPath.StartsWith($taskPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Checksum path outside project'}
    if(!(Test-Path -LiteralPath $taskPath -PathType Leaf)){throw ('Missing release file: '+$taskRelative)}
    if((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash -ne $taskExpected){throw ('Changed release file: '+$taskRelative)}
    $taskCount++
}
Write-Output "PASS release integrity: $taskCount files"
