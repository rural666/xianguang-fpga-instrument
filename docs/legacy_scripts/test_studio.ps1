param()
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$taskSource=Join-Path $taskProject 'controller'
$taskChecks=Join-Path $taskProject 'logs\controls_test.exe'
& $taskCompiler /nologo /target:exe /codepage:65001 "/out:$taskChecks" (Join-Path $taskSource 'ControlsTest.cs') (Join-Path $taskSource 'InstrumentControls.cs') (Join-Path $taskSource 'KeyboardState.cs') (Join-Path $taskSource 'PcmLink.cs')
if($LASTEXITCODE -ne 0){throw 'Control test build failed'}
& $taskChecks
if($LASTEXITCODE -ne 0){throw 'Control tests failed'}
$taskParser=Join-Path $taskProject 'logs\parser_test.exe'
& $taskCompiler /nologo /target:exe /codepage:65001 "/out:$taskParser" (Join-Path $taskSource 'ParserTest.cs') (Join-Path $taskSource 'PcmLink.cs')
if($LASTEXITCODE -ne 0){throw 'Parser test build failed'}
$taskCapture=Join-Path $taskProject 'testdata\hardware_music_capture.bin'
& $taskParser $taskCapture
if($LASTEXITCODE -ne 0){throw 'Audio regression failed'}
$taskFineCapture=Join-Path $taskProject 'testdata\hardware_fine_capture.bin'
& $taskParser $taskFineCapture
if($LASTEXITCODE -ne 0){throw 'Fine-resolution audio regression failed'}
$taskSensor=Join-Path $taskProject 'logs\sensor_test.exe'
& $taskCompiler /nologo /target:exe /codepage:65001 "/out:$taskSensor" (Join-Path $taskSource 'SensorTest.cs') (Join-Path $taskSource 'SensorDiagnostics.cs')
if($LASTEXITCODE -ne 0){throw 'Sensor test build failed'}
& $taskSensor
if($LASTEXITCODE -ne 0){throw 'Sensor tests failed'}
$taskFramework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskReferences=@('WPF\PresentationCore.dll','WPF\PresentationFramework.dll','WPF\WindowsBase.dll','System.Xaml.dll') | ForEach-Object {'/reference:'+(Join-Path $taskFramework $_)}
$taskStage=Join-Path $taskProject 'logs\stage_test.exe'
& $taskCompiler /nologo /target:exe /codepage:65001 "/out:$taskStage" @taskReferences (Join-Path $taskSource 'StageTest.cs') (Join-Path $taskSource 'PianoStage.cs') (Join-Path $taskSource 'InstrumentControls.cs')
if($LASTEXITCODE -ne 0){throw 'Stage test build failed'}
& $taskStage
if($LASTEXITCODE -ne 0){throw 'Stage tests failed'}
