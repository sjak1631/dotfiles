$ErrorActionPreference = 'Stop'

# Zen Browser prefs, written to user.js in every used profile (profile names are random).
# Runs on every apply: a fresh machine has no profile until Zen has been started once.
# Only the block between the markers is managed; anything else in user.js is kept.
# Zen reads user.js at startup, so changes apply after restarting it.
$prefs = @(
    # No tooltips on the browser UI: with a tiling WM, windows move under the cursor and
    # Firefox-based browsers leave tooltips (e.g. a tab's close button) stuck on screen
    'user_pref("browser.chrome.toolbar_tips", false);'
    # No Mica backdrop (Zen's default is on): Windows only draws it on the focused window, so
    # Zen flips between translucent and solid as focus moves. Keep it always opaque instead
    'user_pref("widget.windows.mica", false);'
    # Don't restyle every other Zen window whenever focus moves to a new one
    'user_pref("zen.view.grey-out-inactive-windows", false);'
)

$begin = '// --- managed by chezmoi (sjak1631/dotfiles): begin ---'
$end = '// --- managed by chezmoi: end ---'
$block = (@($begin) + $prefs + @($end)) -join "`r`n"

$profiles = Join-Path $env:APPDATA 'zen\Profiles'
if (-not (Test-Path $profiles)) { exit 0 }

foreach ($dir in Get-ChildItem $profiles -Directory) {
    if (-not (Test-Path (Join-Path $dir.FullName 'prefs.js'))) { continue }  # never used
    $file = Join-Path $dir.FullName 'user.js'
    $current = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { '' }

    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
    $updated = if ($current -match $pattern) {
        [regex]::Replace($current, $pattern, { param($m) $block })
    } else {
        ($current.TrimEnd() + "`r`n" + $block + "`r`n").TrimStart()
    }

    if ($updated -ne $current) {
        [IO.File]::WriteAllText($file, $updated, (New-Object Text.UTF8Encoding $false))
        Write-Host "==> Zen prefs updated: $($dir.Name) (restart Zen to apply)"
    }

    # An earlier version made xulstore.json read-only (to stop Zen restoring its window geometry);
    # GlazeWM now re-tiles Zen after it appears instead, so let Zen save its UI state again
    $xul = Join-Path $dir.FullName 'xulstore.json'
    if ((Test-Path $xul) -and (Get-Item $xul).IsReadOnly) {
        (Get-Item $xul).IsReadOnly = $false
        Write-Host "==> Zen xulstore.json writable again: $($dir.Name)"
    }
}
