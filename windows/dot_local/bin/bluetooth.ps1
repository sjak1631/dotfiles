# Bluetooth helper for the Zebar bluetooth panel (WinRT from Windows PowerShell 5.1).
#   bluetooth.ps1 status    -> JSON {"radio": "On"|"Off"|null, "devices": [{"name", "connected"}]}
#   bluetooth.ps1 on | off  -> switch the Bluetooth radio
#   bluetooth.ps1 settings  -> open Settings > Bluetooth & devices
# Connecting/disconnecting individual (classic) devices has no public API, so it is not offered.
param([Parameter(Mandatory)][ValidateSet('status', 'on', 'off', 'settings')][string]$Action)

$ErrorActionPreference = 'Stop'

if ($Action -eq 'settings') { Start-Process 'ms-settings:bluetooth'; exit 0 }

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await($op, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    [void]$task.Wait(-1)
    $task.Result
}

[void][Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime]
[void][Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType = WindowsRuntime]
[void][Windows.Devices.Bluetooth.BluetoothDevice, Windows.Devices.Bluetooth, ContentType = WindowsRuntime]
[void][Windows.Devices.Bluetooth.BluetoothLEDevice, Windows.Devices.Bluetooth, ContentType = WindowsRuntime]

[void](Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]))
$radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
$radio = $radios | Where-Object { $_.Kind -eq 'Bluetooth' } | Select-Object -First 1

if ($Action -in 'on', 'off') {
    if (-not $radio) { throw 'No Bluetooth radio' }
    $state = if ($Action -eq 'on') { 'On' } else { 'Off' }
    [void](Await ($radio.SetStateAsync($state)) ([Windows.Devices.Radios.RadioAccessStatus]))
    exit 0
}

# status: paired classic + LE devices, deduplicated by name
$devices = @{}
$kinds = @(
    @{ Selector = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromPairingState($true); Type = [Windows.Devices.Bluetooth.BluetoothDevice] }
    @{ Selector = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelectorFromPairingState($true); Type = [Windows.Devices.Bluetooth.BluetoothLEDevice] }
)
foreach ($k in $kinds) {
    $infos = Await ([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($k.Selector)) ([Windows.Devices.Enumeration.DeviceInformationCollection])
    foreach ($info in $infos) {
        try { $dev = Await ($k.Type::FromIdAsync($info.Id)) ($k.Type) } catch { continue }
        if (-not $dev) { continue }
        $connected = "$($dev.ConnectionStatus)" -eq 'Connected'
        $name = if ($dev.Name) { $dev.Name } else { $info.Name }
        if (-not $devices.ContainsKey($name) -or $connected) { $devices[$name] = $connected }
    }
}

[pscustomobject]@{
    radio   = if ($radio) { "$($radio.State)" } else { $null }
    devices = @($devices.GetEnumerator() | Sort-Object { -not $_.Value }, Name | ForEach-Object { [pscustomobject]@{ name = $_.Key; connected = $_.Value } })
} | ConvertTo-Json -Compress -Depth 3
