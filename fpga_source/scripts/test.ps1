param([string[]]$Names=@('tb_uart','tb_i2s','tb_ima','tb_adpcm6','tb_audio_stream','tb_decimate','tb_room','tb_synth','tb_metronome','tb_i2c_reg_xfer','tb_encoder','tb_expression','tb_speaker_volume','tb_speaker_conditioner','tb_speaker_path','tb_mpu6050','tb_mpu6500','tb_control_top','tb_control_report'),[string]$OssRoot='')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$task=Split-Path (Split-Path $project -Parent) -Parent
$oss=if($OssRoot){$OssRoot}else{Join-Path $task 'work\tools\oss-cad-suite'}
if(!(Test-Path -LiteralPath (Join-Path $oss 'bin\iverilog.exe'))){throw 'Set -OssRoot to your OSS CAD Suite directory.'}
$env:PATH=(Join-Path $oss 'bin')+';'+(Join-Path $oss 'lib')+';'+$env:PATH
$rtl=Get-ChildItem -LiteralPath (Join-Path $project 'rtl') -Filter '*.v' | ForEach-Object FullName
New-Item -ItemType Directory -Force -Path (Join-Path $project 'build\sim') | Out-Null
Push-Location $project
try {
    foreach($name in $Names) {
        $target=Join-Path $project ('build\'+$name+'.vvp')
        & (Join-Path $oss 'bin\iverilog.exe') -B (Join-Path $oss 'lib\ivl') -g2012 -Wall -Wno-timescale -s $name -o $target @rtl (Join-Path $project ('sim\'+$name+'.sv'))
        if($LASTEXITCODE -ne 0) { throw "Simulation compile failed: $name" }
        & (Join-Path $oss 'bin\vvp.exe') $target
        if($LASTEXITCODE -ne 0) { throw "Simulation failed: $name" }
    }
} finally { Pop-Location }

