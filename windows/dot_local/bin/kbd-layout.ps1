# Laptop: puts kanata on its `jis` layer (the built-in keyboard's JIS legends on the US layout
# Windows uses) while no external keyboard is connected, and on `base` (plain US) while one is.
# Windows' own per-keyboard layout (KeyboardTypeOverride) can't be used: kanata re-sends every
# key from one device, so Windows sees a single keyboard.
# Started at logon by the dotfiles-kbd-layout task (run_onchange_after_80-autostart). Talks to
# kanata's TCP server (--port, run_onchange_after_20-kanata); each check is a short connection,
# so kanata never blocks writing to a reader that stopped reading. Polling also catches kanata
# restarts, which start it on `base` again.

$port = 7313
# USB (HID\VID_...) and Bluetooth (HID\{service GUID}...) keyboards; the built-in ones are
# ACPI\... (PS/2) and HID collections of laptop buttons
$externalPattern = '^HID\\(VID_|\{)'

function Get-WantedLayer {
    $external = Get-CimInstance Win32_Keyboard | Where-Object PNPDeviceID -match $externalPattern
    if ($external) { 'base' } else { 'jis' }
}

function Sync-Layer([string]$wanted) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', $port)
        $client.ReceiveTimeout = 2000
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true
        $reader = New-Object System.IO.StreamReader($stream)
        $writer.WriteLine('{"RequestCurrentLayerName":{}}')
        # Other notifications (LayerChange, ...) can arrive first
        for ($i = 0; $i -lt 10; $i++) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { return }
            if ($line -match '"CurrentLayerName":\{"name":"([^"]*)"') {
                if ($Matches[1] -ne $wanted) {
                    $writer.WriteLine("{`"ChangeLayer`":{`"new`":`"$wanted`"}}")
                }
                return
            }
        }
    } catch {
        # kanata not running (yet): retried on the next check
    } finally {
        $client.Close()
    }
}

# Device arrivals/removals trigger an immediate check; the timeout is the polling fallback
Register-CimIndicationEvent -ClassName Win32_DeviceChangeEvent -SourceIdentifier kbdLayout | Out-Null
while ($true) {
    Sync-Layer (Get-WantedLayer)
    Wait-Event -SourceIdentifier kbdLayout -Timeout 5 | Out-Null
    # A plug-in fires several events in a row; drain them so one check covers the burst
    Start-Sleep -Milliseconds 500
    Get-Event -SourceIdentifier kbdLayout -ErrorAction SilentlyContinue | Remove-Event
}
