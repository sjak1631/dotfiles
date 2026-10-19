# Hide or restore the Windows taskbar (Zebar replaces it).
#   taskbar.ps1 hide   - auto-hide + hide the taskbar windows on all monitors
#   taskbar.ps1 show   - stop any watcher and restore the normal, always-visible taskbar
#   taskbar.ps1 watch  - hide, and keep it hidden (e.g. after Explorer restarts) while GlazeWM
#                        runs; once GlazeWM is gone, restore the taskbar and exit
param([ValidateSet('hide', 'show', 'watch')][string]$Action = 'hide')

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Taskbar {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }

    [DllImport("shell32.dll")] static extern IntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);

    const uint ABM_SETSTATE = 0xA;
    const int ABS_AUTOHIDE = 1, ABS_ALWAYSONTOP = 2, SW_HIDE = 0, SW_SHOW = 5;

    public static void Set(bool hide) {
        IntPtr tray = FindWindow("Shell_TrayWnd", null);
        if (tray == IntPtr.Zero) return;

        // Auto-hide frees the work area the taskbar reserves; hiding the window stops it popping up
        var d = new APPBARDATA();
        d.cbSize = Marshal.SizeOf(d);
        d.hWnd = tray;
        d.lParam = (IntPtr)(hide ? ABS_AUTOHIDE : ABS_ALWAYSONTOP);
        SHAppBarMessage(ABM_SETSTATE, ref d);

        int cmd = hide ? SW_HIDE : SW_SHOW;
        ShowWindow(tray, cmd);
        IntPtr w = IntPtr.Zero;
        while ((w = FindWindowEx(IntPtr.Zero, w, "Shell_SecondaryTrayWnd", null)) != IntPtr.Zero) ShowWindow(w, cmd);
    }

    // True if any taskbar window is visible again (e.g. Explorer restarted)
    public static bool AnyVisible() {
        IntPtr tray = FindWindow("Shell_TrayWnd", null);
        if (tray != IntPtr.Zero && IsWindowVisible(tray)) return true;
        IntPtr w = IntPtr.Zero;
        while ((w = FindWindowEx(IntPtr.Zero, w, "Shell_SecondaryTrayWnd", null)) != IntPtr.Zero)
            if (IsWindowVisible(w)) return true;
        return false;
    }
}
'@

function Stop-Watchers {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'taskbar\.ps1"?\s+watch' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

switch ($Action) {
    'hide' { [Taskbar]::Set($true) }
    'show' { Stop-Watchers; [Taskbar]::Set($false) }
    'watch' {
        Stop-Watchers  # only one watcher
        [Taskbar]::Set($true)
        while (Get-Process glazewm -ErrorAction SilentlyContinue) {
            Start-Sleep -Seconds 1
            if ([Taskbar]::AnyVisible()) { [Taskbar]::Set($true) }
        }
        [Taskbar]::Set($false)
    }
}
