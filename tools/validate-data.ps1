param([string]$RunRoot = "")
$ErrorActionPreference = "Stop"
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = Join-Path $env:TEMP ("iron-tide-data-" + [guid]::NewGuid().ToString("N"))
}
$taskRun = [IO.Path]::GetFullPath($RunRoot)
if (Test-Path -LiteralPath $taskRun) { throw "RunRoot already exists: $taskRun" }
if ($taskRun.Equals($taskRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $taskRun.StartsWith($taskRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Use a new RunRoot outside the development workspace."
}
$taskProject = Join-Path $taskRun "project"
New-Item -ItemType Directory -Path $taskProject -Force | Out-Null
$taskPreviousProject = $env:IRON_TIDE_PROJECT
try {
    $env:IRON_TIDE_PROJECT = $taskProject
    & robocopy (Join-Path $taskRoot "iron_tide/assets") (Join-Path $taskProject "assets") /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Asset copy failed." }
    foreach ($step in @("build", "validate", "faction")) {
        & node (Join-Path $taskRoot "ra2pipe/$step.mjs") *> (Join-Path $taskRun "$step.log")
        if ($LASTEXITCODE -ne 0) { throw "$step failed; inspect $taskRun" }
    }
    & node (Join-Path $taskRoot "tools/check-assets.mjs") *> (Join-Path $taskRun "assets.json")
    if ($LASTEXITCODE -ne 0) { throw "Missing source assets; inspect $taskRun/assets.json" }
}
finally {
    $env:IRON_TIDE_PROJECT = $taskPreviousProject
}
Write-Output "PASS: data assertions, faction generation and asset sources. Reports: $taskRun"
