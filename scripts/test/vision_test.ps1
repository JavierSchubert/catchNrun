# Runs headless team-vision / fog-of-war / last-known-structure checks.
# This script starts Godot. Run it yourself when you want the test.
#
#   powershell -File scripts/test/vision_test.ps1 -Godot "C:\Path\To\Godot.exe"

param(
    [Parameter(Mandatory = $true)]
    [string] $Godot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Scene = "res://tests/vision/vision_test.tscn"

if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Godot executable not found: $Godot"
}

$argList = "--headless --path `"$ProjectRoot`" $Scene"
$proc = Start-Process -FilePath $Godot -ArgumentList $argList -PassThru -Wait -NoNewWindow
if ($proc.ExitCode -ne 0) {
    Write-Output "FAIL: vision exited with code $($proc.ExitCode)"
    exit $proc.ExitCode
}

Write-Output "PASS: vision"
exit 0
