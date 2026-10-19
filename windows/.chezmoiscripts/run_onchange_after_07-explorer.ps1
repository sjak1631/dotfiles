$ErrorActionPreference = 'Stop'

# Explorer: a clean desktop and no taskbar on secondary monitors. Applied live, no Explorer restart.
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Shell {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);

    // The desktop's view: under Progman, or under a WorkerW once a wallpaper slideshow etc. ran
    static IntPtr DesktopView() {
        IntPtr view = FindWindowEx(FindWindow("Progman", null), IntPtr.Zero, "SHELLDLL_DefView", null);
        IntPtr w = IntPtr.Zero;
        while (view == IntPtr.Zero && (w = FindWindowEx(IntPtr.Zero, w, "WorkerW", null)) != IntPtr.Zero)
            view = FindWindowEx(w, IntPtr.Zero, "SHELLDLL_DefView", null);
        return view;
    }

    // Same as right-click > View > Show desktop icons (toggles and saves HideIcons)
    public static bool ToggleDesktopIcons() {
        IntPtr view = DesktopView();
        if (view == IntPtr.Zero) return false;
        SendMessage(view, 0x0111 /* WM_COMMAND */, (IntPtr)0x7402, IntPtr.Zero);
        return true;
    }

    [DllImport("user32.dll")] static extern bool SystemParametersInfo(uint action, uint param, IntPtr pv, uint winIni);

    // Snap on/off, applied live (same switch as Settings > System > Multitasking > Snap windows)
    public static void SetWindowArranging(bool on) {
        SystemParametersInfo(0x0083 /* SPI_SETWINARRANGING */, on ? 1u : 0u, IntPtr.Zero, 0x01 | 0x02 /* update ini, send change */);
    }

    // Tells Explorer to re-read taskbar settings (what the Settings app does)
    public static void BroadcastTraySettings() {
        IntPtr r;
        SendMessageTimeout((IntPtr)0xFFFF /* HWND_BROADCAST */, 0x001A /* WM_SETTINGCHANGE */, IntPtr.Zero, "TraySettings", 0x0002 /* SMTO_ABORTIFHUNG */, 3000, out r);
    }
}
'@

# Hide all desktop icons (the files stay where they are)
if ((Get-ItemProperty $adv).HideIcons -ne 1) {
    if ([Shell]::ToggleDesktopIcons()) { Write-Host '==> desktop icons hidden' }
    else { Set-ItemProperty $adv -Name HideIcons -Value 1 -Type DWord; Write-Host '==> desktop icons hidden (after next sign-in)' }
}

# No Windows snapping: GlazeWM does the layout. Turns off edge/top snapping and maximizing by
# drag, the layout bar when dragging to the top, the layout flyout on the maximize button,
# Snap Assist suggestions, and Aero Shake.
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WindowArrangementActive -Value '0' -Type String
foreach ($name in 'EnableSnapBar', 'EnableSnapAssistFlyout', 'SnapAssist', 'JointResize', 'SnapFill') {
    Set-ItemProperty $adv -Name $name -Value 0 -Type DWord
}
Set-ItemProperty $adv -Name DisallowShaking -Value 1 -Type DWord
[Shell]::SetWindowArranging($false)
Write-Host '==> Windows snapping off'

# Taskbar only on the main monitor: the side monitor never gets one, not even during logon
# before the taskbar watcher starts
if ((Get-ItemProperty $adv).MMTaskbarEnabled -ne 0) {
    Set-ItemProperty $adv -Name MMTaskbarEnabled -Value 0 -Type DWord
    [Shell]::BroadcastTraySettings()
    Write-Host '==> taskbar on other displays turned off'
}
