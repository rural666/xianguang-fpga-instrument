param([string]$Port='COM4')
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskSp=[System.IO.Ports.SerialPort]::new($Port,230400)
$taskSp.ReadBufferSize=262144
$taskCapture=[System.IO.MemoryStream]::new()
try {
    $taskSp.Open();$taskSp.DiscardInBuffer();$taskSp.Write('Xz');Start-Sleep -Milliseconds 100;$taskSp.DiscardInBuffer()
    $taskSp.Write('bXO1nR!1004;')
    $taskClock=[Diagnostics.Stopwatch]::StartNew();$taskPing=0
    $taskBuffer=[byte[]]::new(16384)
    $taskIndex=0
    $taskEvents=@(
        @{at=300;command='Q2008;'},@{at=1200;command='Q000A;'},
        @{at=1700;command='Q010B;'},@{at=2600;command='Q000A;'},
        @{at=3100;command='Q0912;'},@{at=4400;command='Q000A;'},
        @{at=5500;command='Q2008;'},@{at=6400;command='Q000A;'},
        @{at=6900;command='Q010B;'},@{at=7800;command='Q000A;'},
        @{at=8300;command='Q0912;'},@{at=9600;command='Q000A;'}
    )
    # Allow the previous regression's release tail and level controller to settle.
    while($taskClock.ElapsedMilliseconds -lt 13100){
        if($taskIndex -lt $taskEvents.Count -and $taskClock.ElapsedMilliseconds -ge ($taskEvents[$taskIndex].at+2500)){$taskSp.Write($taskEvents[$taskIndex].command);$taskIndex++}
        if($taskClock.ElapsedMilliseconds -ge $taskPing){$taskSp.Write('k');$taskPing+=180}
        $taskCount=$taskSp.BytesToRead
        if($taskCount -gt 0){$taskRead=$taskSp.Read($taskBuffer,0,[Math]::Min($taskCount,$taskBuffer.Length));$taskCapture.Write($taskBuffer,0,$taskRead)}
        Start-Sleep -Milliseconds 5
    }
    $taskSp.Write('Xz')
    [IO.File]::WriteAllBytes((Join-Path $taskProject 'logs\board_piano_demo.bin'),$taskCapture.ToArray())
    Write-Output "Board piano demo finished, $($taskCapture.Length) telemetry bytes; no PC audio API used."
} finally {try{if($taskSp.IsOpen){$taskSp.Write('Xz')}}catch{};$taskSp.Dispose();$taskCapture.Dispose()}
