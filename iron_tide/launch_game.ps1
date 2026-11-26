param([switch]$PrepareOnly)

$ErrorActionPreference = 'Stop'
$taskLogRoot = Join-Path $env:LOCALAPPDATA 'IronTide/startup-logs'
$taskStamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$taskImportLog = Join-Path $taskLogRoot ($taskStamp + '-import.log')
try {
    $taskEngine = $env:IRON_TIDE_GODOT
    if ([string]::IsNullOrWhiteSpace($taskEngine)) {
        $taskEngine = Join-Path $env:LOCALAPPDATA 'Programs/Godot/Godot_v4.7.2-stable_win64.exe'
    }
    if (-not (Test-Path -LiteralPath $taskEngine -PathType Leaf)) { throw "Godot not found: $taskEngine" }
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'project.godot'))) { throw 'project.godot is missing.' }
    New-Item -ItemType Directory -Path $taskLogRoot -Force | Out-Null
    # A normal Godot game process does not discover new class_name scripts.
    # Import in a separate process, then start the game with the refreshed registry.
    $taskImporter = $taskEngine -replace '\.exe$', '_console.exe'
    if (-not (Test-Path -LiteralPath $taskImporter)) { $taskImporter = $taskEngine }
    Write-Host 'Preparing scripts and resources. Please wait...'
    & $taskImporter --headless --path $PSScriptRoot --import --log-file $taskImportLog *> ($taskImportLog + '.console.txt')
    $taskImportExit = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $taskImportLog)) { throw 'Godot did not produce an import log.' }
    $taskLog = [IO.File]::ReadAllText($taskImportLog)
    if ($taskImportExit -ne 0 -or $taskLog -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw 'Script/resource preparation failed; the game was not started.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.godot/global_script_class_cache.cfg'))) {
        throw 'Godot did not generate the script class registry.'
    }
    # Import with the editor, but play with the locally installed release runtime.
    # An explicit IRON_TIDE_GODOT override retains its previous play-engine behavior.
    $taskRuntime = $env:IRON_TIDE_RUNTIME
    if ([string]::IsNullOrWhiteSpace($taskRuntime)) {
        $taskRuntime = $taskEngine
        $taskLocalRuntime = Join-Path $PSScriptRoot 'IronTideRuntime.exe'
        if ([string]::IsNullOrWhiteSpace($env:IRON_TIDE_GODOT) -and (Test-Path -LiteralPath $taskLocalRuntime -PathType Leaf)) {
            $taskRuntime = $taskLocalRuntime
        }
    }
    if (-not (Test-Path -LiteralPath $taskRuntime -PathType Leaf)) { throw "Runtime not found: $taskRuntime" }
    if ($taskRuntime -ne $taskEngine) {
        $taskEditorVersion = ((& $taskEngine --version) | Out-String).Trim()
        $taskRuntimeVersion = ((& $taskRuntime --version) | Out-String).Trim()
        if ($taskEditorVersion -ne $taskRuntimeVersion) { throw 'Editor and play runtime versions differ. Refresh the local release runtime.' }
    }
    Write-Host ("Play runtime: " + $taskRuntime)
    if (-not $PrepareOnly) {
        # Normal play must not inherit an opt-in performance probe from a shell.
        $env:IRON_TIDE_CALL_LOG = '0'
        # Capture only this run's stderr. Godot keeps its normal player log as well.
        $taskRunLog = Join-Path $taskLogRoot ($taskStamp + '-runtime.log')
        $taskStart = @{
            FilePath = $taskRuntime
            WorkingDirectory = $PSScriptRoot
            RedirectStandardError = $taskRunLog
            Wait = $true
            PassThru = $true
        }
        if ($taskRuntime -eq $taskEngine) {
            $taskStart.ArgumentList = @('--path', ('"' + $PSScriptRoot + '"'))
        }
        $taskGame = Start-Process @taskStart
        $taskFailure = Select-String -LiteralPath $taskRunLog -Encoding UTF8 -Pattern '^\s*(?:(?:SCRIPT ERROR|ERROR|FATAL(?: ERROR)?|PANIC)\s*:|CrashHandlerException\b)' -List -Context 0,20
        if ($taskFailure -or $taskGame.ExitCode -ne 0) {
            Write-Host ("Game exit code: " + $taskGame.ExitCode)
            if ($taskFailure) {
                Write-Host $taskFailure.Line
                $taskFailure.Context.PostContext | ForEach-Object { Write-Host $_ }
            } else {
                Get-Content -LiteralPath $taskRunLog -Encoding UTF8 -Tail 20
            }
            Write-Host ("Runtime log: " + $taskRunLog)
            exit 1
        }
    }
    Write-Host 'Ready.'
    exit 0
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Import log: ' + $taskImportLog)
    exit 1
}
