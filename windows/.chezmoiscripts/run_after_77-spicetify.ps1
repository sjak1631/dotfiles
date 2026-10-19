$ErrorActionPreference = 'Stop'

# Spotify theming with Spicetify: the "Rice" theme (AppData/Roaming/spicetify/Themes/Rice,
# generated from rice.yaml) and the rice-start.js extension. Runs on every apply but only patches Spotify when the theme, Spotify
# or Spicetify changed: Spotify's auto-updates undo the patch, and the next apply redoes it.
# Doesn't restart Spotify; a running Spotify picks the theme up on its next start.

$spotify = Join-Path $env:APPDATA 'Spotify\Spotify.exe'
if (-not (Test-Path $spotify)) { exit 0 }
if (-not (Test-Path (Join-Path $env:APPDATA 'Spotify\prefs'))) {
    Write-Host '==> Spicetify: start Spotify once (it creates its prefs), then run chezmoi apply again'
    exit 0
}
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (Get-Command spicetify -ErrorAction SilentlyContinue)) { exit 0 }

$theme = Join-Path $env:APPDATA 'spicetify\Themes\Rice'
$extension = Join-Path $env:APPDATA 'spicetify\Extensions\rice-start.js'
$parts = @((Get-Item $spotify).VersionInfo.FileVersion, (spicetify --version))
$parts += @(Get-ChildItem $theme -File | Sort-Object Name) + @(Get-Item $extension) | ForEach-Object { (Get-FileHash $_.FullName).Hash }
$hash = ($parts -join ' ').Trim()
$stateFile = Join-Path $env:LOCALAPPDATA 'dotfiles\spicetify.hash'
if ((Test-Path $stateFile) -and (Get-Content $stateFile -Raw).Trim() -eq $hash) { exit 0 }

function Invoke-Spicetify([string[]]$arguments) {
    $ErrorActionPreference = 'Continue'
    $out = & spicetify -n @arguments 2>&1 | Out-String
    $ok = $LASTEXITCODE -eq 0 -and $out -notmatch '(?m)^\s*\S*\s*error\b'
    [pscustomobject]@{ Ok = $ok; Output = $out.Trim() }
}

Write-Host '==> Spicetify: applying the Rice theme'
$r = Invoke-Spicetify @('config', 'current_theme', 'Rice', 'color_scheme', 'Base', 'inject_css', '1', 'replace_colors', '1', 'overwrite_assets', '0')
if (-not $r.Ok) { throw "spicetify config failed:`n$($r.Output)" }
# rice-start.js: opens a playlist on startup ("extensions" is a list; adding it twice is a no-op)
if ((Get-Content (spicetify -c) -Raw) -notmatch '(?m)^[ \t]*extensions[ \t]*=.*rice-start\.js') {
    $r = Invoke-Spicetify @('config', 'extensions', 'rice-start.js')
    if (-not $r.Ok) { throw "spicetify config extensions failed:`n$($r.Output)" }
}

# First run: back up Spotify's original files. After a Spotify update the backup is stale:
# restore, back up the new version, apply.
$ini = Get-Content (spicetify -c) -Raw
$hasBackup = $ini -match '(?m)^[ \t]*version[ \t]*=[ \t]*\S'
$r = if ($hasBackup) { Invoke-Spicetify @('apply') } else { Invoke-Spicetify @('backup', 'apply') }
if (-not $r.Ok -and $hasBackup) { $r = Invoke-Spicetify @('restore', 'backup', 'apply') }
if (-not $r.Ok) { throw "spicetify apply failed:`n$($r.Output)" }

New-Item -ItemType Directory -Force (Split-Path $stateFile) | Out-Null
Set-Content $stateFile $hash -Encoding ascii
Write-Host '==> Spicetify: Rice theme applied (restart Spotify to see it)'
