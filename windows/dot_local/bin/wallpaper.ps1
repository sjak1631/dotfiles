# Wallpaper switcher. Images live in ~/Pictures/Wallpapers (any mix of landscape/portrait;
# orientation is detected). Landscape monitors and the lock screen cycle through landscape
# images, portrait monitors through portrait ones (or landscape ones if there are none).
#   wallpaper.ps1 next | prev | random     - switch
#   wallpaper.ps1 apply                    - re-apply the current selection (also updates the lock screen)
# Picking from a list: type "wp" in Flow Launcher (plugin in AppData/Roaming/FlowLauncher/Plugins/Wallpaper).
#   wallpaper.ps1 set <landscape> [<portrait>]  - set specific files (name in the folder, or a full path)
# The current selection is per machine state in %LOCALAPPDATA%\dotfiles\wallpaper.json.
param(
    [ValidateSet('next', 'prev', 'random', 'apply', 'set')][string]$Action = 'apply',
    [string]$Landscape,
    [string]$Portrait
)
$ErrorActionPreference = 'Stop'

$dir = Join-Path $HOME 'Pictures\Wallpapers'
$stateDir = Join-Path $env:LOCALAPPDATA 'dotfiles'
$stateFile = Join-Path $stateDir 'wallpaper.json'
$fallback = 'C:\Windows\Web\Wallpaper\Windows\img19.jpg'
New-Item -ItemType Directory -Force $stateDir | Out-Null

# ---- desktop wallpaper helper (compiled once, cached as a DLL: Add-Type compiling takes ~1s) ----
$source = @'
using System;
using System.Runtime.InteropServices;

public static class DesktopWallpaper {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IDesktopWallpaper {
        void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint monitorIndex);
        uint GetMonitorDevicePathCount();
        void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID, out RECT rect);
        void SetBackgroundColor(uint color);
        uint GetBackgroundColor();
        void SetPosition(int position);
        int GetPosition();
    }

    [ComImport, Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")] class DesktopWallpaperClass { }

    // Sets `portrait` on monitors taller than wide and `landscape` on the rest (Fill)
    public static void Apply(string landscape, string portrait) {
        var dw = (IDesktopWallpaper)new DesktopWallpaperClass();
        dw.SetPosition(4);  // DWPOS_FILL
        uint n = dw.GetMonitorDevicePathCount();
        for (uint i = 0; i < n; i++) {
            string id = dw.GetMonitorDevicePathAt(i);
            RECT r;
            try { dw.GetMonitorRECT(id, out r); } catch { continue; }  // not attached
            dw.SetWallpaper(id, (r.Bottom - r.Top) > (r.Right - r.Left) ? portrait : landscape);
        }
    }
}
'@
$sha = [Security.Cryptography.SHA256]::Create()
$hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($source))[0..5] | ForEach-Object { $_.ToString('x2') })
$dll = Join-Path $stateDir "DesktopWallpaper-$hash.dll"
if (-not (Test-Path $dll)) {
    Get-ChildItem $stateDir -Filter 'DesktopWallpaper-*.dll' | Remove-Item -Force -ErrorAction SilentlyContinue
    Add-Type -TypeDefinition $source -OutputAssembly $dll
}
Add-Type -Path $dll

# ---- collection ----
function Get-Images {
    $landscapes = @(); $portraits = @()
    if (Test-Path $dir) {
        Add-Type -AssemblyName System.Drawing
        foreach ($f in Get-ChildItem $dir -File | Where-Object Extension -match '^\.(jpe?g|png|bmp)$' | Sort-Object Name) {
            $stream = [IO.File]::OpenRead($f.FullName)
            try {
                # Reads only the header (no full decode)
                $img = [System.Drawing.Image]::FromStream($stream, $false, $false)
                if ($img.Height -gt $img.Width) { $portraits += $f.FullName } else { $landscapes += $f.FullName }
                $img.Dispose()
            } catch { } finally { $stream.Dispose() }
        }
    }
    @{ Landscape = $landscapes; Portrait = $portraits }
}

function Resolve-Image([string]$name) {
    if (-not $name) { return $null }
    $path = if ([IO.Path]::IsPathRooted($name)) { $name } else { Join-Path $dir $name }
    if (-not (Test-Path $path)) { throw "Wallpaper not found: $path" }
    (Resolve-Path $path).Path
}

function Step([string[]]$list, [string]$current, [int]$delta) {
    if ($list.Count -eq 0) { return $null }
    if ($delta -eq 0) { return $list[(Get-Random -Maximum $list.Count)] }
    $i = [Array]::IndexOf($list, $current)
    if ($i -lt 0) { return $list[0] }
    $list[(($i + $delta) % $list.Count + $list.Count) % $list.Count]
}

$state = @{ landscape = $null; portrait = $null }
if (Test-Path $stateFile) {
    try { $s = Get-Content $stateFile -Raw | ConvertFrom-Json; $state.landscape = $s.landscape; $state.portrait = $s.portrait } catch { }
}

switch ($Action) {
    'set' {
        $state.landscape = Resolve-Image $Landscape
        $state.portrait = Resolve-Image $Portrait
    }
    { $_ -in 'next', 'prev', 'random' } {
        $delta = @{ next = 1; prev = -1; random = 0 }[$Action]
        $images = Get-Images
        $l = Step $images.Landscape $state.landscape $delta
        if ($l) { $state.landscape = $l }
        $p = Step $images.Portrait $state.portrait $delta
        $state.portrait = $p  # null = use the landscape image
    }
}

$landscapePath = if ($state.landscape -and (Test-Path $state.landscape)) { $state.landscape } else { $fallback }
$portraitPath = if ($state.portrait -and (Test-Path $state.portrait)) { $state.portrait } else { $landscapePath }

[DesktopWallpaper]::Apply($landscapePath, $portraitPath)
$state | ConvertTo-Json | Set-Content $stateFile -Encoding UTF8
Write-Host "==> wallpaper: $landscapePath | portrait: $portraitPath"

# ---- lock screen (same landscape image) ----
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
$asTaskOp = $asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$asTaskAction = $asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
$fileTask = $asTaskOp.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($landscapePath)))
[void]$fileTask.Wait(-1)
[void]$asTaskAction.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($fileTask.Result))).Wait(-1)
