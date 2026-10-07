param()
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$taskFramework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskReferences=@('WPF\PresentationCore.dll','WPF\PresentationFramework.dll','WPF\WindowsBase.dll','System.Xaml.dll') | ForEach-Object {'/reference:'+(Join-Path $taskFramework $_)}
$taskSources=@('Studio.cs','PianoStage.cs','InstrumentControls.cs','PcmLink.cs','KeyboardState.cs','SensorDiagnostics.cs') | ForEach-Object {Join-Path $taskProject "controller\$_"}
$taskOutput=Join-Path $taskProject 'controller\TangStudio.exe'
& $taskCompiler /nologo /target:winexe /codepage:65001 /optimize+ "/out:$taskOutput" @taskReferences @taskSources
if($LASTEXITCODE -ne 0){throw 'Studio build failed'}
Get-FileHash -LiteralPath $taskOutput -Algorithm SHA256
