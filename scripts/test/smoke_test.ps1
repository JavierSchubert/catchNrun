# Repeatable multiplayer smoke test.
# This script starts Godot. Run it yourself when you want the test; it is not run by the editor.
#
#   powershell -File scripts/test/smoke_test.ps1 -Godot "C:\Path\To\Godot.exe"
#
# It hosts one headless game, joins one Hunter bot and two Runner bots, then checks the
# JSON reports those processes write under tests/multiplayer/reports/.

param(
    [Parameter(Mandatory = $true)]
    [string] $Godot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ReportDir = Join-Path $ProjectRoot "tests\multiplayer\reports"

if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Godot executable not found: $Godot"
}

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
Get-ChildItem -LiteralPath $ReportDir -Filter *.json -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $ReportDir -Filter *.log -ErrorAction SilentlyContinue | Remove-Item -Force

function Start-Game {
    param(
        [string] $UserArgs,
        [string] $LogName
    )
    $logOut = Join-Path $ReportDir "$LogName.out.log"
    $logErr = Join-Path $ReportDir "$LogName.err.log"
    # One quoted string so paths that contain spaces stay one argument.
    $argList = "--headless --path `"$ProjectRoot`" $UserArgs"
    return Start-Process -FilePath $Godot -ArgumentList $argList -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $logOut -RedirectStandardError $logErr
}

$hostReport = Join-Path $ReportDir "host.json"
$runner1Report = Join-Path $ReportDir "runner1.json"
$runner2Report = Join-Path $ReportDir "runner2.json"
$hunterReport = Join-Path $ReportDir "hunter.json"

Write-Output "Starting host"
$hostProc = Start-Game -LogName "host" -UserArgs "-- --host --player-name=Host --auto-start=4 --head-start=1 --host-lifetime=20 --report=`"$hostReport`""
Start-Sleep -Seconds 2
Write-Output "Starting bots"
$runner1 = Start-Game -LogName "runner1" -UserArgs "-- --bot=runner --bot-name=`"Runner 1`" --bot-lifetime=14 --report=`"$runner1Report`""
$runner2 = Start-Game -LogName "runner2" -UserArgs "-- --bot=runner --bot-name=`"Runner 2`" --bot-lifetime=14 --report=`"$runner2Report`""
$hunter = Start-Game -LogName "hunter" -UserArgs "-- --bot=hunter --bot-name=`"Hunter`" --bot-lifetime=14 --report=`"$hunterReport`""

$procs = @($hostProc, $runner1, $runner2, $hunter)
$deadline = (Get-Date).AddSeconds(50)
$timedOut = $false
foreach ($proc in $procs) {
    $remaining = [int](($deadline - (Get-Date)).TotalMilliseconds)
    if ($remaining -lt 1000) { $remaining = 1000 }
    if (-not $proc.WaitForExit($remaining)) {
        Write-Output "Timed out waiting for process $($proc.Id) ($($proc.ProcessName))."
        $timedOut = $true
    }
}
if ($timedOut) {
    foreach ($proc in $procs) {
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Output "FAIL: a game process did not exit. Logs are in $ReportDir"
    exit 1
}

function Read-Report {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing report $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

$failures = @()
foreach ($proc in $procs) {
    $proc.Refresh()
    if ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
        $failures += "Process $($proc.Id) exited with code $($proc.ExitCode)."
    }
}

try {
    $hostResult = Read-Report $hostReport
    $runner1Result = Read-Report $runner1Report
    $runner2Result = Read-Report $runner2Report
    $hunterResult = Read-Report $hunterReport
} catch {
    Write-Output "FAIL: $($_.Exception.Message)"
    Write-Output "Logs are in $ReportDir"
    exit 1
}

$phases = As-Array $hostResult.phases
if ($hostResult.kind -ne "host") { $failures += "Host report kind is '$($hostResult.kind)'." }
if ($phases -notcontains "ROLE_SELECTION") { $failures += "Host never opened role selection." }
if ($phases -notcontains "RUNNER_PREPARATION") { $failures += "Host never entered runner preparation." }
if ($phases -notcontains "HUNTER_ACTIVE") { $failures += "Host never entered the hunter phase." }
if ($hostResult.hunter_spawned -ne $true) { $failures += "Hunter did not spawn." }
if ($hostResult.hunter_spawned_during_preparation -eq $true) { $failures += "Hunter spawned during preparation." }
if ([int] $hostResult.runner_spawn_count -lt 3) { $failures += "Expected at least 3 runner spawns, got $($hostResult.runner_spawn_count)." }

$roster = As-Array $hostResult.players_at_hunter_phase
$rosterHunters = @($roster | Where-Object { $_.role -eq "Hunter" })
$rosterRunners = @($roster | Where-Object { $_.role -eq "Runner" })
if ($rosterHunters.Count -ne 1) { $failures += "Expected 1 hunter in the roster, got $($rosterHunters.Count)." }
if ($rosterRunners.Count -lt 3) { $failures += "Expected at least 3 runners in the roster, got $($rosterRunners.Count)." }

function Assert-Bot {
    param($Report, [string] $Role, [string] $Label)
    if ($Report.kind -ne "bot") { $script:failures += "$Label is not a bot report." }
    if ($Report.requested_role -ne $Role) { $script:failures += "$Label requested '$($Report.requested_role)', expected $Role." }
    if ($Report.assigned_role -ne $Role) { $script:failures += "$Label was assigned '$($Report.assigned_role)', expected $Role." }
    if ($Report.connected -ne $true) { $script:failures += "$Label did not connect." }
    if ($Report.spawned -ne $true) { $script:failures += "$Label did not spawn." }
    if ($Report.moved -ne $true) { $script:failures += "$Label did not move." }
    if ($Report.disconnected_cleanly -ne $true) { $script:failures += "$Label did not disconnect cleanly." }
    $botErrors = As-Array $Report.errors
    if ($botErrors.Count -gt 0) { $script:failures += "$Label errors: $($botErrors -join '; ')" }
}

Assert-Bot $runner1Result "Runner" "Runner 1"
Assert-Bot $runner2Result "Runner" "Runner 2"
Assert-Bot $hunterResult "Hunter" "Hunter"

if ($failures.Count -gt 0) {
    Write-Output "FAIL"
    $failures | ForEach-Object { Write-Output " - $_" }
    Write-Output "Logs and reports are in $ReportDir"
    exit 1
}

Write-Output "PASS: host, 2 runners, and 1 hunter connected, spawned, moved, and disconnected."
exit 0
