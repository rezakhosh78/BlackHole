param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'core')).TrimEnd('\') + '\'
$runtimeRoot = Join-Path $appRoot 'runtime'
$statePath = Join-Path $runtimeRoot 'session-state.json'

function Stop-OwnedProcess {
    param([AllowNull()]$ProcessId, [string]$ExpectedName)
    if ($null -eq $ProcessId) { return }
    $process = Get-Process -Id ([int]$ProcessId) -ErrorAction SilentlyContinue
    if ($null -eq $process) { return }
    $processPath = $process.Path
    if ([string]::IsNullOrWhiteSpace($processPath)) { return }
    $fullPath = [System.IO.Path]::GetFullPath($processPath)
    if ($process.ProcessName -ieq $ExpectedName -and
        $fullPath.StartsWith($coreRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Restore-ProxyState {
    param($Backup)
    if ($null -eq $Backup) { return }
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    foreach ($name in @('ProxyEnable','ProxyServer','ProxyOverride')) {
        $state = $Backup.$name
        if ([bool]$state.Exists) {
            $type = if ($name -eq 'ProxyEnable') { 'DWord' } else { 'String' }
            Set-ItemProperty -Path $path -Name $name -Type $type -Value $state.Value
        } else {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        }
    }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BlackHoleStopWinInet {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int option, IntPtr buffer, int length);
}
'@
    [void][BlackHoleStopWinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][BlackHoleStopWinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
}

if (Test-Path $statePath) {
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    Stop-OwnedProcess -ProcessId $state.xrayPid -ExpectedName 'xray'
    Stop-OwnedProcess -ProcessId $state.winwsPid -ExpectedName 'winws2'
    Restore-ProxyState -Backup $state.proxyBackup
}

foreach ($name in @('active-config.json','active-hosts.txt','active-gray-ip.txt','session-state.json')) {
    Remove-Item -LiteralPath (Join-Path $runtimeRoot $name) -Force -ErrorAction SilentlyContinue
}

Write-Host 'Black Hole session stopped and proxy settings restored.'
