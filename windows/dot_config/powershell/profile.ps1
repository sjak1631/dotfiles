# PowerShell profile (managed by chezmoi). $PROFILE only dot-sources this file, since its own
# location depends on where Documents is (OneDrive or not); see run_onchange_after_85-shell.ps1.

# Terminals opened from GlazeWM inherit its environment from sign-in time, which misses PATH
# entries (and the variables below) added by installs since then: take PATH from the registry
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

# Also set as user environment variables (run_onchange_after_85-shell.ps1)
$env:YAZI_CONFIG_HOME = Join-Path $HOME '.config\yazi'
$gitFile = Join-Path $env:ProgramFiles 'Git\usr\bin\file.exe'
if (Test-Path $gitFile) { $env:YAZI_FILE_ONE = $gitFile }

# y: yazi, then cd to the directory it was left in
function y {
    $tmp = (New-TemporaryFile).FullName
    yazi.exe @args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
