@rem The plugin's entry point (plugin.json). Smart App Control blocks a locally built exe, so the
@rem compiled plugin runs inside the signed Windows PowerShell instead (Wallpaper.ps1).
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Wallpaper.ps1" %*
