param([string]$Port='COM4')
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$taskSource=Join-Path $taskProject 'controller'
$taskLive=Join-Path $taskProject 'logs\live_check.exe'
$taskFiles=@('LiveBoardCheck.cs','PcmLink.cs','InstrumentControls.cs') | ForEach-Object {Join-Path $taskSource $_}
& $taskCompiler /nologo /codepage:65001 /target:exe ('/out:'+$taskLive) @taskFiles
if($LASTEXITCODE -ne 0){throw 'Live test build failed'}
& $taskLive $Port | Tee-Object -FilePath (Join-Path $taskProject 'logs\live_verification.txt')
if($LASTEXITCODE -ne 0){throw 'Real board regression failed'}
