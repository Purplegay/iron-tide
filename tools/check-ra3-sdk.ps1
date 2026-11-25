param([string]$SdkRoot = (Join-Path $PSScriptRoot '../refs/ra3-sdk/installed'))
$ErrorActionPreference = 'Stop'
$SdkRoot = [IO.Path]::GetFullPath($SdkRoot)
$run = Join-Path $SdkRoot ('validation/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $run | Out-Null
$source = Join-Path $run 'irontide-sdk-check.xml'
@'
<?xml version="1.0" encoding="UTF-8"?>
<AssetDeclaration xmlns="uri:ea.com:eala:asset">
  <ArmorTemplate id="IronTideSdkCheck" Default="100">
    <Armor Damage="CANNON" Percent="75" />
  </ArmorTemplate>
</AssetDeclaration>
'@ | Set-Content -LiteralPath $source -Encoding utf8
$output = Join-Path $run 'output'
$process = Start-Process -FilePath "$SdkRoot/Tools/BinaryAssetBuilder.exe" `
    -ArgumentList "`"$source`"", "/od:`"$output`"", "/iod:`"$output`"", '/ls:true', '/gui:false', '/pc:true', '/vf:false', '/el:0' `
    -WorkingDirectory "$SdkRoot/Tools" -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$run/compiler.log" -RedirectStandardError "$run/compiler-error.log"
$process.WaitForExit()
$compilerExit = $process.ExitCode
$log = Get-Content "$run/compiler.log" -Raw
if ($compilerExit -ne 0 -or $log -match '(?i)Error:|Critical:' -or $log -notmatch 'BinaryAssetBuilder complete') {
    throw "SDK compile failed ($compilerExit). Logs: $run"
}
$manifest = Get-ChildItem -LiteralPath $output -Recurse -Filter 'irontide-sdk-check.manifest'
if (-not $manifest -or $manifest.Length -eq 0) { throw 'SDK did not produce a manifest' }
$package = Join-Path $run 'irontide-sdk-check.big'
$process = Start-Process -FilePath "$SdkRoot/Tools/MakeBig.exe" `
    -ArgumentList '-f', "`"$output`"", '-x:*.asset', "-o:`"$package`"" `
    -WorkingDirectory "$SdkRoot/Tools" -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$run/package.log" -RedirectStandardError "$run/package-error.log"
$process.WaitForExit()
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $package)) {
    throw "SDK packaging failed. Logs: $run"
}
$result = [ordered]@{sdk=$SdkRoot;compiler_exit=$compilerExit;packager_exit=$process.ExitCode;
    manifest=$manifest.FullName;package=$package;package_sha256=(Get-FileHash -LiteralPath $package).Hash;
    game_launch_tested=$false;environment='Windows, local .NET Framework 4, x86 SDK compatibility';reports=$run}
$result | ConvertTo-Json | Set-Content "$run/result.json" -Encoding utf8
$result | ConvertTo-Json
