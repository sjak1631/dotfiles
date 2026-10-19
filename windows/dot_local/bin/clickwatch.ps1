# Prints "x y" (physical screen coordinates) for every mouse button press, system-wide.
# The Zebar panel widget runs this to close itself when the user clicks elsewhere.
# The hook only queues events; a separate thread writes them, so a slow reader can never
# stall mouse input.
# It must exit together with Zebar: it inherits Zebar's handles, including the socket of
# Zebar's local server (127.0.0.1:6124), and a leftover copy keeps the next Zebar's widgets
# from loading. So it watches the parent process as well as stdout.

$parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public static class ClickWatch {
    delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    struct MSLLHOOKSTRUCT { public int X, Y; public uint MouseData, Flags, Time; public IntPtr ExtraInfo; }

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);

    const int WH_MOUSE_LL = 14, WM_LBUTTONDOWN = 0x201, WM_RBUTTONDOWN = 0x204, WM_MBUTTONDOWN = 0x207;

    static readonly HookProc Proc = OnMouse;  // keep the delegate alive
    static readonly BlockingCollection<string> Queue = new BlockingCollection<string>();
    static IntPtr hook;

    static IntPtr OnMouse(int code, IntPtr wParam, IntPtr lParam) {
        int msg = wParam.ToInt32();
        if (code >= 0 && (msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN || msg == WM_MBUTTONDOWN)) {
            var s = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));
            Queue.Add(s.X + " " + s.Y);
        }
        return CallNextHookEx(hook, code, wParam, lParam);
    }

    public static void Run(int parentPid) {
        var watchdog = new Thread(() => {
            try { Process.GetProcessById(parentPid).WaitForExit(); } catch { }
            Environment.Exit(0);  // parent gone
        });
        watchdog.IsBackground = true;
        watchdog.Start();

        var writer = new Thread(() => {
            try {
                foreach (var line in Queue.GetConsumingEnumerable()) { Console.Out.WriteLine(line); Console.Out.Flush(); }
            } catch { }
            Environment.Exit(0);  // stdout closed
        });
        writer.IsBackground = true;
        writer.Start();

        hook = SetWindowsHookEx(WH_MOUSE_LL, Proc, GetModuleHandle(null), 0);
        Application.Run();
    }
}
'@

[ClickWatch]::Run($parentPid)
