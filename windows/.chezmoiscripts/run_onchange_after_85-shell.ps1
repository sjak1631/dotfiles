$ErrorActionPreference = 'Stop'

# Shell environment:
#   - $PROFILE (Windows PowerShell and PowerShell 7) dot-sources ~/.config/powershell/profile.ps1
#   - yazi reads its config from ~/.config/yazi (same layout as on Linux) and finds `file`
#     (from Git for Windows), which it needs to detect file types
# Environment variables are per-user so they also apply to yazi started outside a shell.

$line = '. "$HOME\.config\powershell\profile.ps1"'
$documents = [Environment]::GetFolderPath('MyDocuments')
foreach ($profilePath in (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
                         (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1')) {
    $current = if (Test-Path $profilePath) { [IO.File]::ReadAllText($profilePath) } else { '' }
    if ($current -notmatch [regex]::Escape($line)) {
        New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
        [IO.File]::WriteAllText($profilePath, ($current.TrimEnd() + "`r`n" + $line + "`r`n").TrimStart(), (New-Object Text.UTF8Encoding $true))
        Write-Host "==> profile hooked: $profilePath"
    }
}

$vars = @{ YAZI_CONFIG_HOME = Join-Path $HOME '.config\yazi' }
$file = Join-Path $env:ProgramFiles 'Git\usr\bin\file.exe'
if (Test-Path $file) { $vars.YAZI_FILE_ONE = $file }
foreach ($name in $vars.Keys) {
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $vars[$name]) {
        [Environment]::SetEnvironmentVariable($name, $vars[$name], 'User')
        Write-Host "==> $name set"
    }
}
