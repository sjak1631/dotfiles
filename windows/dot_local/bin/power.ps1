# Power actions for the Zebar power panel.
param([Parameter(Mandatory)][ValidateSet('lock', 'sleep', 'signout', 'restart', 'shutdown')][string]$Action)

switch ($Action) {
    'lock'     { rundll32.exe user32.dll,LockWorkStation }
    # SetSuspendState via WinForms sleeps even when hibernation is enabled
    'sleep'    { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false) }
    'signout'  { shutdown.exe /l }
    'restart'  { shutdown.exe /r /t 0 }
    'shutdown' { shutdown.exe /s /t 0 }
}
