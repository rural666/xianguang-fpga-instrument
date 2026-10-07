param([string]$Port='COM4')
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$taskOutput=Join-Path $taskProject 'logs\capture.exe'
& $taskCompiler /nologo /codepage:65001 /target:exe ('/out:'+$taskOutput) (Join-Path $taskProject 'controller\Capture.cs')
if($LASTEXITCODE -ne 0){throw 'Capture build failed'}
& $taskOutput $Port (Join-Path $taskProject 'logs\hardware_music_capture.bin') 230400 30000
if($LASTEXITCODE -ne 0){throw 'Capture failed'}
