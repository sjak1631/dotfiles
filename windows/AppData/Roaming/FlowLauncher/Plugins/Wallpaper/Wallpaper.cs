// Flow Launcher plugin (Executable, JSON-RPC v1): pick a wallpaper from ~/Pictures/Wallpapers.
// Compiled to Wallpaper.dll by run_onchange_after_65-flow-wallpaper.ps1 (C# 5, .NET Framework)
// and run by Wallpaper.cmd -> Wallpaper.ps1 (Smart App Control blocks a locally built exe).
//
// Flow runs `Wallpaper.cmd <request json>` and reads {"result": [...]} from stdout.
//   query <search>  -> one result per image, with a large preview
//   set <path>      -> landscape image: landscape monitors, portrait image: portrait monitors
//   open <dir>      -> open the wallpaper folder
// The selection is shared with wallpaper.ps1 via %LOCALAPPDATA%\dotfiles\wallpaper.json.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;

public static class Program {
    static readonly string Home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    static readonly string Dir = Path.Combine(Home, @"Pictures\Wallpapers");
    static readonly string StateFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"dotfiles\wallpaper.json");
    static readonly string[] Extensions = { ".jpg", ".jpeg", ".png", ".bmp" };
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();

    public static int Main(string[] args) {
        Console.OutputEncoding = new UTF8Encoding(false);
        try {
            var request = Json.Deserialize<Dictionary<string, object>>(args.Length > 0 ? args[0] : "{}");
            string method = Get(request, "method") as string ?? "";
            // JavaScriptSerializer turns JSON arrays into ArrayList
            var parameters = Get(request, "parameters") as System.Collections.IList;
            string arg = parameters != null && parameters.Count > 0 ? Convert.ToString(parameters[0]) : "";

            switch (method) {
                case "query": Write(Query(arg)); break;
                case "set": Set(arg); Write(new List<object>()); break;
                case "open": Process.Start("explorer.exe", "\"" + arg + "\""); Write(new List<object>()); break;
                default: Write(new List<object>()); break;
            }
            return 0;
        } catch (Exception e) {
            Write(new List<object> { Item("エラー: " + e.Message, e.GetType().Name, null, null, null) });
            return 1;
        }
    }

    // Flow serializes keys in camelCase or PascalCase depending on version
    static object Get(Dictionary<string, object> d, string key) {
        foreach (var kv in d) if (string.Equals(kv.Key, key, StringComparison.OrdinalIgnoreCase)) return kv.Value;
        return null;
    }

    static void Write(List<object> results) {
        Console.Out.Write(Json.Serialize(new Dictionary<string, object> { { "result", results } }));
    }

    static Dictionary<string, object> Item(string title, string sub, string icon, Dictionary<string, object> action, string preview) {
        var r = new Dictionary<string, object> { { "Title", title }, { "SubTitle", sub } };
        if (icon != null) r["IcoPath"] = icon;
        if (action != null) r["JsonRPCAction"] = action;
        // IsMedia (big preview) renders nothing in Flow 2.1.3: its MaxWidth binding resolves to 0
        if (preview != null) r["Preview"] = new Dictionary<string, object> { { "PreviewImagePath", preview }, { "IsMedia", false } };
        return r;
    }

    static Dictionary<string, object> Action(string method, string arg) {
        return new Dictionary<string, object> { { "method", method }, { "parameters", new object[] { arg } } };
    }

    // ---- query ----
    static List<object> Query(string search) {
        var results = new List<object>();
        if (!Directory.Exists(Dir) || !Images().Any()) {
            Directory.CreateDirectory(Dir);
            results.Add(Item("壁紙がありません", Dir + " に画像を置いてください (Enter でフォルダを開く)", null, Action("open", Dir), null));
            return results;
        }

        var state = LoadState();
        string q = (search ?? "").Trim();
        var files = Images().Where(f => q.Length == 0 || Path.GetFileName(f).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
        int score = files.Count;
        foreach (var f in files) {
            Size size = ImageSize(f);
            bool portrait = size.Height > size.Width;
            bool current = PathEquals(f, portrait ? state.Portrait : state.Landscape);
            string sub = (portrait ? "縦置きモニター用" : "横長") + "  " + size.Width + "x" + size.Height + (current ? "  · 設定中" : "");
            string thumb = Thumbnail(f);
            var item = Item(Path.GetFileName(f), sub, thumb, Action("set", f), null);
            item["Score"] = score--;  // keep the folder order
            results.Add(item);
        }
        if (results.Count == 0) results.Add(Item("一致する壁紙がありません", "\"" + q + "\"", null, null, null));
        return results;
    }

    static IEnumerable<string> Images() {
        if (!Directory.Exists(Dir)) return new string[0];
        return Directory.GetFiles(Dir)
            .Where(f => Extensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .OrderBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase);
    }

    // Reads only the header, no full decode
    static Size ImageSize(string path) {
        try {
            using (var s = File.OpenRead(path))
            using (var img = Image.FromStream(s, false, false)) return img.Size;
        } catch { return new Size(0, 0); }
    }

    // Icons and previews use cached 640px-wide copies (full-size photos make the list slow),
    // keyed by path + size + modification time
    static readonly string ThumbDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"dotfiles\wallpaper-thumbs");

    static string Thumbnail(string path) {
        try {
            var info = new FileInfo(path);
            string key = path.ToLowerInvariant() + "|" + info.Length + "|" + info.LastWriteTimeUtc.Ticks;
            string name;
            using (var sha = System.Security.Cryptography.SHA1.Create())
                name = BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(key))).Replace("-", "").Substring(0, 16) + ".jpg";
            string thumb = Path.Combine(ThumbDir, name);
            if (File.Exists(thumb)) return thumb;

            Directory.CreateDirectory(ThumbDir);
            using (var img = Image.FromFile(path)) {
                int w = Math.Min(640, img.Width);
                int h = Math.Max(1, img.Height * w / img.Width);
                using (var bmp = new Bitmap(w, h))
                using (var g = Graphics.FromImage(bmp)) {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.DrawImage(img, 0, 0, w, h);
                    bmp.Save(thumb, System.Drawing.Imaging.ImageFormat.Jpeg);
                }
            }
            return thumb;
        } catch { return path; }
    }

    static bool PathEquals(string a, string b) {
        if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return false;
        try { return string.Equals(Path.GetFullPath(a), Path.GetFullPath(b), StringComparison.OrdinalIgnoreCase); }
        catch { return false; }
    }

    // ---- state (shared with wallpaper.ps1) ----
    class State { public string Landscape; public string Portrait; }

    static State LoadState() {
        var s = new State();
        try {
            var d = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(StateFile));
            s.Landscape = Get(d, "landscape") as string;
            s.Portrait = Get(d, "portrait") as string;
        } catch { }
        return s;
    }

    static void SaveState(State s) {
        Directory.CreateDirectory(Path.GetDirectoryName(StateFile));
        File.WriteAllText(StateFile, Json.Serialize(new Dictionary<string, object> { { "landscape", s.Landscape }, { "portrait", s.Portrait } }));
    }

    // ---- set ----
    static void Set(string path) {
        if (!File.Exists(path)) throw new FileNotFoundException("Wallpaper not found", path);
        var state = LoadState();
        Size size = ImageSize(path);
        if (size.Height > size.Width) state.Portrait = path; else state.Landscape = path;

        string landscape = state.Landscape != null && File.Exists(state.Landscape) ? state.Landscape : path;
        string portrait = state.Portrait != null && File.Exists(state.Portrait) ? state.Portrait : landscape;
        Desktop.Apply(landscape, portrait);
        SaveState(state);

        // The lock screen needs WinRT; let wallpaper.ps1 do it in the background (no window)
        string script = Path.Combine(Home, @".local\bin\wallpaper.ps1");
        if (File.Exists(script)) {
            Process.Start(new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" apply") {
                UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden
            });
        }
    }
}

public static class Desktop {
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
