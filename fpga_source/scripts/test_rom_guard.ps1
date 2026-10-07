param()
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskFixture=Join-Path $taskProject ('logs\rom_guard_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path (Join-Path $taskFixture 'rtl') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $taskFixture 'scripts') -Force | Out-Null
$taskValidator=Join-Path $PSScriptRoot 'validate_roms.ps1'
function Assert-RomFailure([string]$Expected){
    $taskFailed=$false
    try{& $taskValidator -Project $taskFixture | Out-Null}catch{
        if($_.Exception.Message -notmatch $Expected){throw}
        $taskFailed=$true
    }
    if(!$taskFailed){throw ('Guard incorrectly accepted: '+$Expected)}
    Write-Output ('PASS rejection: '+$Expected)
}
Assert-RomFailure 'Required audio ROM missing'
Copy-Item -LiteralPath (Join-Path $taskProject 'rtl\sine2048.hex') -Destination (Join-Path $taskFixture 'rtl\sine2048.hex')
Assert-RomFailure 'Required audio ROM missing: ima_steps'
Copy-Item -LiteralPath (Join-Path $taskProject 'rtl\ima_steps.hex') -Destination (Join-Path $taskFixture 'rtl\ima_steps.hex')
& $taskValidator -Project $taskFixture
$taskFixtureSine=Join-Path $taskFixture 'rtl\sine2048.hex'
'0000' | Set-Content -LiteralPath $taskFixtureSine -Encoding ASCII
Assert-RomFailure 'Invalid audio ROM words'
$taskData=[System.IO.File]::ReadAllText((Join-Path $taskProject 'rtl\sine2048.hex'))
$taskChanged='FFFF'+$taskData.Substring(4)
[System.IO.File]::WriteAllText($taskFixtureSine,$taskChanged,[System.Text.Encoding]::ASCII)
Assert-RomFailure 'Audio ROM differs'
& $taskValidator -Project $taskProject
Write-Output 'PASS production ROMs unchanged'
