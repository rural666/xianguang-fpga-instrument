param([string]$GowinRoot=$env:GOWIN_HOME)
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
if(!$GowinRoot){throw 'Pass -GowinRoot or set GOWIN_HOME to the installed Gowin directory.'}
$taskCompiler=Join-Path $GowinRoot 'IDE/bin/gw_sh.exe'
if(!(Test-Path -LiteralPath $taskCompiler)){throw 'Gowin IDE/bin/gw_sh.exe was not found under -GowinRoot.'}
foreach($taskDirectory in @('logs','build/firmware')){New-Item -ItemType Directory -Path (Join-Path $taskProject $taskDirectory) -Force | Out-Null}
& (Join-Path $PSScriptRoot 'validate_roms.ps1') -Project $taskProject
$taskTcl=(Join-Path $PSScriptRoot 'build.tcl').Replace('\','/')
$taskLog=Join-Path $taskProject 'logs/build_fpga.log'
& $taskCompiler $taskTcl *> $taskLog
$taskResult=$LASTEXITCODE
$taskText=Get-Content -LiteralPath $taskLog -Raw
if($taskResult -ne 0 -or $taskText -notmatch 'Bitstream generation completed' -or $taskText -match 'Cannot open file|ERROR\s*\('){throw 'FPGA build failed. Read fpga_source/logs/build_fpga.log.'}
$taskFirmware=Join-Path $taskProject 'build/firmware/control.fs'
Copy-Item -LiteralPath (Join-Path $taskProject 'impl/pnr/control.fs') -Destination $taskFirmware -Force
[ordered]@{baseline='v2.1.2';sha256=(Get-FileHash -LiteralPath $taskFirmware).Hash;file_bytes=(Get-Item -LiteralPath $taskFirmware).Length;programmed=$false} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskProject 'build/firmware/manifest.json') -Encoding UTF8
Write-Output 'Built build/firmware/control.fs offline. Bundled baseline firmware is unchanged. No hardware was programmed.'
