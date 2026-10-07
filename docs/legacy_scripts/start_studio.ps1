param([string]$Port='', [switch]$Offline, [switch]$Quiet,
    [string]$GowinRoot='D:\devtools\FPGA\Gowin_Education_1.9.11.03\Gowin_V1.9.11.03_Education_x64')
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskExe=Join-Path $taskProject 'controller\TangStudio.exe'
$taskArgs=@()
if(!$Offline){
    try{
        if(!$Port){
            $taskPorts=@(Get-PnpDevice -PresentOnly -Class Ports -ErrorAction SilentlyContinue | Where-Object {$_.InstanceId -match '^FTDIBUS\\VID_0403\+PID_6010\+.*B\\0000$'})
            if($taskPorts.Count -eq 1 -and $taskPorts[0].FriendlyName -match '\((COM\d+)\)'){$Port=$Matches[1]}
            elseif([System.IO.Ports.SerialPort]::GetPortNames() -contains 'COM4'){$Port='COM4'}
            else{throw '未检测到开发板 USB 串口，已打开动画预览'}
        }
        $taskProbe=[System.IO.Ports.SerialPort]::new($Port,230400)
        try{$taskProbe.Open()}finally{$taskProbe.Dispose()}
        $taskFirmware=Join-Path $taskProject 'firmware\control.fs'
        $taskManifest=Get-Content -LiteralPath (Join-Path $taskProject 'firmware\manifest.json') -Raw | ConvertFrom-Json
        if((Get-FileHash -LiteralPath $taskFirmware -Algorithm SHA256).Hash -ne $taskManifest.sha256){throw '固件文件校验失败，请重新解压完整安装包'}
        $taskProgrammer=Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
        $taskScan=& $taskProgrammer --scan --cable-index 4 --channel 0 --frequency 2.5MHz 2>&1
        if($LASTEXITCODE -ne 0 -or ($taskScan -join "`n") -notmatch '0x0000081B'){throw '未检测到 Tang Nano 20K，请检查开发板 USB 连接'}
        & $taskProgrammer --device GW2AR-18C --run 2 --cable-index 4 --channel 0 --frequency 2.5MHz --fsFile $taskFirmware *> (Join-Path $taskProject 'logs\program.log')
        if($LASTEXITCODE -ne 0 -or (Get-Content -LiteralPath (Join-Path $taskProject 'logs\program.log') -Raw) -notmatch 'Finished\.'){throw '开发板临时固件加载失败，请查看 logs/program.log'}
        $taskArgs+=$Port
    }catch{
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $taskProject 'logs\launch_status.txt') -Encoding UTF8
        $taskArgs+='--launch-failed'
        $Offline=$true
    }
}
if($Offline){$taskArgs+='--offline'}
if($Quiet){$taskArgs+='--quiet'}
Start-Process -FilePath $taskExe -ArgumentList $taskArgs -WorkingDirectory $taskProject -WindowStyle Normal
