# Hide or restore the Windows taskbar (Zebar + Flow Launcher replace it).
#   taskbar.ps1 hide   - hide the taskbar on all monitors
#   taskbar.ps1 show   - stop any watcher and restore the normal taskbar
#   taskbar.ps1 watch  - hide, and keep it hidden while GlazeWM runs; once GlazeWM is gone,
#                        restore the taskbar and exit
#
# Hiding = auto-hide (frees the work area) + hidden taskbar windows. A hidden auto-hide taskbar
# does not slide back in at the screen edge. Re-sending the auto-hide state, however, makes
# Explorer show the taskbar, so it is only sent when auto-hide is actually off.
param([ValidateSet('hide', 'show', 'watch')][string]$Action = 'hide')

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public static class Taskbar {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }
    delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time);

    [DllImport("shell32.dll")] static extern IntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder name, int max);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventProc fn, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    const uint ABM_GETSTATE = 0x4, ABM_SETSTATE = 0xA;
    const int ABS_AUTOHIDE = 1, ABS_ALWAYSONTOP = 2, SW_HIDE = 0, SW_SHOW = 5;
    const uint EVENT_OBJECT_SHOW = 0x8002, WINEVENT_OUTOFCONTEXT = 0;

    // Zebar's systray provider creates its own "Shell_TrayWnd" to receive tray icons,
    // so only windows owned by explorer.exe are the real taskbar.
    static bool IsExplorer(IntPtr hwnd) {
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        try { return Process.GetProcessById((int)pid).ProcessName.Equals("explorer", StringComparison.OrdinalIgnoreCase); }
        catch { return false; }
    }

    static IntPtr MainTray() {
        IntPtr w = IntPtr.Zero;
        while ((w = FindWindowEx(IntPtr.Zero, w, "Shell_TrayWnd", null)) != IntPtr.Zero)
            if (IsExplorer(w)) return w;
        return IntPtr.Zero;
    }

    static List<IntPtr> Windows() {
        var list = new List<IntPtr>();
        IntPtr tray = MainTray();
        if (tray != IntPtr.Zero) list.Add(tray);
        IntPtr w = IntPtr.Zero;
        while ((w = FindWindowEx(IntPtr.Zero, w, "Shell_SecondaryTrayWnd", null)) != IntPtr.Zero)
            if (IsExplorer(w)) list.Add(w);
        return list;
    }

    static bool IsTaskbar(IntPtr hwnd) {
        var sb = new StringBuilder(64);
        GetClassName(hwnd, sb, sb.Capacity);
        string c = sb.ToString();
        return c == "Shell_TrayWnd" || c == "Shell_SecondaryTrayWnd";
    }

    static APPBARDATA Data() {
        var d = new APPBARDATA();
        d.cbSize = Marshal.SizeOf(d);
        d.hWnd = MainTray();
        return d;
    }

    static void SetAutoHide(bool on) {
        var d = Data();
        if (d.hWnd == IntPtr.Zero) return;
        bool isOn = (SHAppBarMessage(ABM_GETSTATE, ref d).ToInt64() & ABS_AUTOHIDE) != 0;
        if (isOn == on) return;  // re-sending pops the taskbar up
        d.lParam = (IntPtr)(on ? ABS_AUTOHIDE : ABS_ALWAYSONTOP);
        SHAppBarMessage(ABM_SETSTATE, ref d);
    }

    public static void Hide() {
        SetAutoHide(true);
        foreach (var w in Windows()) ShowWindow(w, SW_HIDE);
    }

    public static void Show() {
        foreach (var w in Windows()) ShowWindow(w, SW_SHOW);
        SetAutoHide(false);
    }

    static readonly WinEventProc OnShow = (hook, ev, hwnd, idObject, idChild, thread, time) => {
        if (idObject == 0 && hwnd != IntPtr.Zero && IsTaskbar(hwnd)) ShowWindow(hwnd, SW_HIDE);
    };

    // Re-hides the taskbar the moment Explorer shows it, until GlazeWM exits
    public static void Watch() {
        Hide();
        uint hookedPid = 0;
        IntPtr hook = IntPtr.Zero;

        var lastCheck = DateTime.MinValue;
        while (true) {
            Application.DoEvents();  // delivers the WinEvent callbacks
            Thread.Sleep(20);
            if ((DateTime.Now - lastCheck).TotalSeconds < 1) continue;
            lastCheck = DateTime.Now;
            if (Process.GetProcessesByName("glazewm").Length == 0) break;

            // (Re)hook Explorer's show events when it (re)starts; only Explorer's events
            uint pid = 0;
            IntPtr tray = MainTray();
            if (tray != IntPtr.Zero) GetWindowThreadProcessId(tray, out pid);
            if (pid != 0 && pid != hookedPid) {
                if (hook != IntPtr.Zero) UnhookWinEvent(hook);
                hook = SetWinEventHook(EVENT_OBJECT_SHOW, EVENT_OBJECT_SHOW, IntPtr.Zero, OnShow, pid, 0, WINEVENT_OUTOFCONTEXT);
                hookedPid = pid;
                Hide();
            }

            // Safety net (e.g. new taskbar windows after an Explorer restart)
            SetAutoHide(true);
            foreach (var w in Windows()) if (IsWindowVisible(w)) ShowWindow(w, SW_HIDE);
        }
        if (hook != IntPtr.Zero) UnhookWinEvent(hook);
        Show();
    }
}
'@

function Stop-Watchers {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'taskbar\.ps1"?\s+watch' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

switch ($Action) {
    'hide' { [Taskbar]::Hide() }
    'show' { Stop-Watchers; [Taskbar]::Show() }
    'watch' { Stop-Watchers; [Taskbar]::Watch() }
}
