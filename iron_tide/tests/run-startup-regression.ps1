param([Parameter(Mandatory=$true)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$taskSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskRun = [IO.Path]::GetFullPath($RunRoot)
if ((Test-Path -LiteralPath $taskRun) -or $taskRun.StartsWith($taskSource, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use a new external RunRoot.'
}
$taskProject = Join-Path $taskRun 'project with spaces'
New-Item -ItemType Directory -Path $taskProject -Force | Out-Null
& robocopy $taskSource $taskProject /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Project copy failed.' }
$taskConfigPath = Join-Path $taskProject 'project.godot'
$taskConfig = [IO.File]::ReadAllText($taskConfigPath)
$taskConfig = [regex]::Replace($taskConfig, '(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\r?\n', '')
$taskUser = 'CodexIronTideValidation/' + [guid]::NewGuid().ToString('N')
$taskConfig = $taskConfig.Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$taskUser`"")
$taskConfig = $taskConfig.Replace('[autoload]', "[autoload]`nStartupRegression=`"*res://tests/startup_regression.gd`"")
[IO.File]::WriteAllText($taskConfigPath, $taskConfig, [Text.UTF8Encoding]::new($false))
$taskCache = Join-Path $taskProject '.godot/global_script_class_cache.cfg'
$taskOriginalCache = [IO.File]::ReadAllText($taskCache)
$taskStaleCache = [regex]::Replace($taskOriginalCache, '(?s)\{[^{}]*"class": &"AlliedAbilities"[^{}]*\},?\s*', '')
if ($taskStaleCache -eq $taskOriginalCache) { throw 'Expected AlliedAbilities in source registry.' }
[IO.File]::WriteAllText($taskCache, $taskStaleCache)
$taskEngine = Join-Path $env:LOCALAPPDATA 'Programs/Godot/Godot_v4.7.2-stable_win64_console.exe'
$taskOldReport = $env:IRON_TIDE_REPORT_DIR
$taskOldEngine = $env:IRON_TIDE_GODOT
try {
    $taskBefore = Join-Path $taskRun 'before'
    New-Item -ItemType Directory -Path $taskBefore | Out-Null
    $env:IRON_TIDE_REPORT_DIR = $taskBefore
    & $taskEngine --path $taskProject --log-file (Join-Path $taskBefore 'godot.log') *> (Join-Path $taskBefore 'console.log')
    $taskBeforeLog = [IO.File]::ReadAllText((Join-Path $taskBefore 'godot.log'))
    if ($taskBeforeLog -notmatch 'Identifier "AlliedAbilities" not declared') { throw 'Stale registry failure was not reproduced.' }
    $taskAfter = Join-Path $taskRun 'after'
    New-Item -ItemType Directory -Path $taskAfter | Out-Null
    $env:IRON_TIDE_REPORT_DIR = $taskAfter
    $env:IRON_TIDE_GODOT = $taskEngine
    # Actual shipped BAT -> Windows PowerShell -> import -> fresh game process.
    & $env:ComSpec /d /c ('call "' + (Join-Path $taskProject '启动游戏.bat') + '"')
    if ($LASTEXITCODE -ne 0) { throw 'Launcher failed.' }
    $taskResultPath = Join-Path $taskAfter 'result.json'
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not (Test-Path -LiteralPath $taskResultPath) -and [DateTime]::UtcNow -lt $taskDeadline) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path -LiteralPath $taskResultPath)) { throw 'Launched game did not finish its real menu/battle check.' }
    $taskResult = Get-Content -LiteralPath $taskResultPath -Raw | ConvertFrom-Json
    if ($taskResult.failed -ne 0) { throw 'Real menu/battle check failed.' }
    $taskPlayerLog = Join-Path $env:APPDATA (Join-Path $taskUser 'logs/godot.log')
    Copy-Item -LiteralPath $taskPlayerLog -Destination (Join-Path $taskAfter 'godot.log')
    if ([IO.File]::ReadAllText($taskPlayerLog) -match '(?m)^(SCRIPT ERROR|ERROR):') { throw 'Runtime reported errors.' }
    # An actual syntax error must stop preparation even if the editor exits 0.
    $taskBadScript = Join-Path $taskProject 'scripts/units/allied_abilities.gd'
    $taskGoodScript = [IO.File]::ReadAllText($taskBadScript)
    [IO.File]::AppendAllText($taskBadScript, "`nfunc broken(:`n")
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $taskProject 'launch_game.ps1') -PrepareOnly *> (Join-Path $taskRun 'rejected-import.log')
    $taskRejected = $LASTEXITCODE -ne 0
    [IO.File]::WriteAllText($taskBadScript, $taskGoodScript, [Text.UTF8Encoding]::new($false))
    if (-not $taskRejected) { throw 'Broken script was not blocked.' }
    [ordered]@{stale_registry_reproduced=$true; actual_bat_passed=$true; battle_checks=$taskResult.checks.Count; broken_import_blocked=$taskRejected; project=$taskProject; custom_user_dir=$taskUser; engine=$taskEngine; network='none'; database='none'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRun 'summary.json') -Encoding UTF8
    Write-Output "PASS: stale cache reproduced, BAT launch and $($taskResult.checks.Count) battle checks passed, bad import blocked. $taskRun"
} finally {
    $env:IRON_TIDE_REPORT_DIR = $taskOldReport
    $env:IRON_TIDE_GODOT = $taskOldEngine
}
