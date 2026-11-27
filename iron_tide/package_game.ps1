param(
    [string]$OutputDirectory,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$stage = $null

function Read-GodotVersion([string]$Executable) {
    $log = [IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $Executable -ArgumentList '--version' -RedirectStandardOutput $log -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Cannot read version: $Executable" }
        return ([IO.File]::ReadAllText($log)).Trim()
    } finally {
        Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
    }
}

try {
    $project = $PSScriptRoot
    $runner = Join-Path (Split-Path -Parent $project) 'tools/package_windows.py'
    $licenses = Join-Path $project 'tools/packaging'
    $godot = $env:IRON_TIDE_GODOT
    if (-not $godot) { $godot = Join-Path $env:LOCALAPPDATA 'Programs/Godot/Godot_v4.7.2-stable_win64_console.exe' }
    $console = $godot -replace '(?<!_console)\.exe$', '_console.exe'
    if (Test-Path -LiteralPath $console -PathType Leaf) { $godot = $console }
    $runtime = $env:IRON_TIDE_RUNTIME
    if (-not $runtime) { $runtime = Join-Path $project 'IronTideRuntime.exe' }

    $python = $env:IRON_TIDE_PYTHON
    if (-not $python) {
        $installed = @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs/Python') -Directory -Filter 'Python*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'python.exe' })
        $commands = @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*\Microsoft\WindowsApps\*' } | ForEach-Object { $_.Source })
        foreach ($candidate in ($installed + $commands)) {
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
            & $candidate -c 'import sys; sys.exit(sys.version_info < (3, 11))'
            if ($LASTEXITCODE -eq 0) { $python = $candidate; break }
        }
    }
    if (-not $python) { throw 'Python 3.11+ not found. Set IRON_TIDE_PYTHON to python.exe.' }
    & $python -c 'import sys; sys.exit(sys.version_info < (3, 11))'
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.11 or newer is required.' }
    $null = Get-Command git.exe
    foreach ($path in @($runner, $godot, $runtime, (Join-Path $licenses 'Godot-LICENSE.txt'), (Join-Path $licenses 'Godot-THIRD-PARTY.txt'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required file: $path" }
    }
    $editorVersion = Read-GodotVersion $godot
    $runtimeVersion = Read-GodotVersion $runtime
    if (-not $editorVersion -or $editorVersion -ne $runtimeVersion) {
        throw "Godot editor and release runtime must match: $editorVersion / $runtimeVersion"
    }
    $config = Get-Content -LiteralPath (Join-Path $project 'project.godot') -Raw -Encoding UTF8
    if ($config -notmatch '(?m)^config/version="([0-9A-Za-z._-]+)"') { throw 'Cannot read the game version.' }
    $version = $Matches[1]
    if (-not $OutputDirectory) { $OutputDirectory = Join-Path $env:USERPROFILE 'Downloads' }
    $OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
    $stage = Join-Path (Join-Path $env:LOCALAPPDATA 'IronTide/package-builds') $stamp
    $output = Join-Path $OutputDirectory ("IronTide-$version-Windows-x64-$stamp.zip")
    Write-Host "Godot: $editorVersion"
    Write-Host "Build logs: $stage"
    Write-Host "ZIP: $output"
    if ($CheckOnly) { Write-Host 'Preflight passed. No package generated.'; exit 0 }

    & $python -u $runner --source $project --stage $stage --output $output --godot $godot --template $runtime --licenses $licenses
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'Export or verification failed. No finished ZIP was delivered.' }
    Write-Host "Ready: $output" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($stage) { Write-Host "Build logs: $stage" }
    exit 1
}
