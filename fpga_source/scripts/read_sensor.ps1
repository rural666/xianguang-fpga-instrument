param([string]$Port='COM4',[int]$Seconds=20,[switch]$ExerciseControls)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$path=Join-Path $project ('logs\sensors_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.jsonl')
$sp=[System.IO.Ports.SerialPort]::new($Port,230400)
$sp.ReadTimeout=500;$sp.WriteTimeout=500;$sp.DtrEnable=$false;$sp.RtsEnable=$false
$count=0;$previous='';$last=$null
try {
    $sp.Open();$sp.DiscardInBuffer();$sp.Write('Xzn')
    # Discard old bytes held by the onboard bridge, not only the Windows buffer.
    $sp.ReadTimeout=40;$stale=[byte[]]::new(8192);$drainUntil=[DateTime]::UtcNow.AddMilliseconds(500)
    while([DateTime]::UtcNow -lt $drainUntil){try{$null=$sp.Read($stale,0,$stale.Length)}catch [System.TimeoutException]{}}
    $sp.ReadTimeout=500
    $until=[DateTime]::UtcNow.AddSeconds($Seconds)
    while([DateTime]::UtcNow -lt $until) {
        try {$line=$sp.ReadLine().Trim()}catch [System.TimeoutException]{continue}
        if($line -notmatch '^TN20K_CTL5 H=[0-9A-F]{8} .* C=[0-9A-F]{4}$'){continue}
        $record=[ordered]@{time=(Get-Date).ToString('o')}
        foreach($m in [regex]::Matches($line,'(?:^| )([A-Z]+)=([0-9A-F]+)')) {
            $name=$m.Groups[1].Value;$value=[Convert]::ToInt64($m.Groups[2].Value,16)
            if($name -in @('AX','AY','AZ','GX','GY','GZ','TP') -and $value -ge 32768){$value-=65536}
            if($name -eq 'POS' -and $value -ge 2147483648){$value-=4294967296}
            $record[$name]=$value
        }
        $record['raw']=$line
        $record | ConvertTo-Json -Compress | Add-Content -LiteralPath $path -Encoding UTF8
        $fingerprint=('{0}/{1}/{2}/{3}/{4}/{5}' -f $record.M,$record.A,$record.ERR,$record.T,$record.E,$record.G)
        if($count -lt 3 -or $previous -ne $fingerprint){Write-Output $line}
        $previous=$fingerprint;$count++;$last=$record
        if($ExerciseControls -and $count -eq 5){$sp.Write('3m')}
        if($ExerciseControls -and $count -eq 20){$sp.Write('1n')}
    }
    $sp.Write('Xn')
}finally{$sp.Dispose()}
if(!$count){throw 'No valid control telemetry. Load the v0.5 SRAM firmware.'}
$last | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'logs\latest_sensor.json') -Encoding UTF8
Write-Output ('RECORDS='+$count+' LOG='+$path)
Write-Output $last.raw
