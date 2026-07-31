param()

$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = Join-Path $appRoot 'runtime'
$errorLog = Join-Path $runtimeRoot 'launcher-error.log'

try {
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdministrator) {
        Start-Process powershell.exe -Verb RunAs -WorkingDirectory $appRoot -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-STA',
            '-File', "`"$PSCommandPath`""
        ) -ErrorAction Stop
        exit 0
    }

    $requiredFiles = @(
        (Join-Path $appRoot 'BlackHole.ps1'),
        (Join-Path $appRoot 'BlackHole.Core.psm1'),
        (Join-Path $appRoot 'core\xray\xray.exe'),
        (Join-Path $appRoot 'core\desync\winws2.exe'),
        (Join-Path $appRoot 'core\desync\cygwin1.dll'),
        (Join-Path $appRoot 'core\desync\WinDivert.dll'),
        (Join-Path $appRoot 'core\desync\WinDivert64.sys'),
        (Join-Path $appRoot 'core\desync\lua\engine-lib.lua'),
        (Join-Path $appRoot 'core\desync\lua\engine-antidpi.lua')
    )

    $missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
    if ($missing.Count -gt 0) {
        throw "The package is incomplete. Missing file(s):`r`n$($missing -join "`r`n")"
    }

    $syntaxFiles = @(
        (Join-Path $appRoot 'BlackHole.ps1'),
        (Join-Path $appRoot 'BlackHole.Core.psm1'),
        (Join-Path $appRoot 'Stop-BlackHole.ps1')
    )
    foreach ($syntaxFile in $syntaxFiles) {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $syntaxFile,
            [ref]$tokens,
            [ref]$parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            $first = $parseErrors[0]
            throw "PowerShell syntax validation failed in $syntaxFile at line $($first.Extent.StartLineNumber): $($first.Message)"
        }
    }

    # Starting the native core with --version catches missing runtime DLLs before
    # the GUI opens. A missing DLL otherwise causes Windows to terminate the
    # process before it can write a useful stdout/stderr message.
    $nativeCore = Join-Path $appRoot 'core\desync\winws2.exe'
    $nativeTestOut = Join-Path $runtimeRoot 'native-selftest-stdout.log'
    $nativeTestErr = Join-Path $runtimeRoot 'native-selftest-stderr.log'
    Remove-Item -LiteralPath $nativeTestOut,$nativeTestErr -Force -ErrorAction SilentlyContinue
    $nativeTest = Start-Process -FilePath $nativeCore -ArgumentList '--version' `
        -WorkingDirectory (Split-Path $nativeCore -Parent) -WindowStyle Hidden `
        -RedirectStandardOutput $nativeTestOut -RedirectStandardError $nativeTestErr `
        -Wait -PassThru
    if ($nativeTest.ExitCode -ne 0) {
        $nativeText = @(
            if (Test-Path $nativeTestOut) { Get-Content $nativeTestOut -Raw -ErrorAction SilentlyContinue }
            if (Test-Path $nativeTestErr) { Get-Content $nativeTestErr -Raw -ErrorAction SilentlyContinue }
        ) -join [Environment]::NewLine
        throw "The Desync core self-test failed (exit code $($nativeTest.ExitCode)). $nativeText"
    }

    & (Join-Path $appRoot 'BlackHole.ps1')
} catch {
    $details = @(
        "Black Hole could not start.",
        "",
        $_.Exception.Message,
        "",
        "Time: $((Get-Date).ToString('o'))"
    ) -join [Environment]::NewLine

    try {
        $details | Set-Content -LiteralPath $errorLog -Encoding UTF8
    } catch {}

    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Black Hole could not start.`r`n`r`n$($_.Exception.Message)`r`n`r`nError log:`r`n$errorLog",
            'Black Hole - Startup error',
            'OK',
            'Error'
        ) | Out-Null
    } catch {
        Write-Host $details -ForegroundColor Red
    }
    exit 1
}
