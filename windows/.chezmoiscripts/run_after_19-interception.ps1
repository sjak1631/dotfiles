$ErrorActionPreference = 'Stop'

# Interception keyboard/mouse filter driver, used by kanata's "wintercept" build.
# kanata's default build (winIOv2) uses a low-level keyboard hook; Windows skips a hook that's
# slow to respond, so key releases were sometimes lost and Ctrl stayed stuck down. The driver
# sits below that and doesn't lose events.
# Runs on every apply: installs the driver once (UAC, then a reboot), and keeps interception.dll
# next to the kanata executables (kanata loads it from there).
# Known issue: after very many device reconnects the driver can stop passing keyboard/mouse input
# until the next reboot (oblitum/Interception#25).

$url = 'https://github.com/oblitum/Interception/releases/download/v1.0.1/Interception.zip'
$sha256 = 'AD038963D6413055765128B0B931F6E765147C9916DBA79E65D872B261F9AF10'
$cache = Join-Path $env:LOCALAPPDATA 'dotfiles\interception'
$dll = Join-Path $cache 'interception.dll'

$installed = Test-Path (Join-Path $env:SystemRoot 'System32\drivers\keyboard.sys')

if (-not $installed -or -not (Test-Path $dll)) {
    $tmp = Join-Path $env:TEMP "interception-$PID"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        $zip = Join-Path $tmp 'Interception.zip'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
        if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $sha256) { throw "Interception.zip: unexpected SHA256" }
        Expand-Archive $zip (Join-Path $tmp 'x') -Force
        $root = Join-Path $tmp 'x\Interception'

        New-Item -ItemType Directory -Force $cache | Out-Null
        Copy-Item (Join-Path $root 'library\x64\interception.dll') $dll -Force

        if (-not $installed) {
            Write-Host '==> installing the Interception driver (UAC prompt)'
            $p = Start-Process (Join-Path $root 'command line installer\install-interception.exe') -ArgumentList '/install' -Verb RunAs -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "install-interception.exe failed (exit $($p.ExitCode))" }
            Write-Host '==> Interception driver installed: reboot to activate it (kanata starts at the next logon)'
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$kanataDir = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Directory -Filter 'jtroo.kanata_gui_*' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($kanataDir) {
    $target = Join-Path $kanataDir.FullName 'interception.dll'
    if (-not (Test-Path $target) -or (Get-FileHash $target).Hash -ne (Get-FileHash $dll).Hash) {
        Copy-Item $dll $target -Force
        Write-Host '==> interception.dll placed next to kanata'
    }
}
