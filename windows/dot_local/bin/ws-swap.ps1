# Swaps the focused GlazeWM workspace with workspace <name>, contents and layout included, by
# renaming the two (GlazeWM has no swap command). If <name> has no windows (so it doesn't exist),
# the focused workspace just takes that name. Run from GlazeWM's alt+ctrl+<n> bindings.
param([Parameter(Mandatory)][string]$Name)

$cli = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\cli\glazewm.exe'
$workspaces = (& $cli query workspaces | ConvertFrom-Json).data.workspaces
$current = ($workspaces | Where-Object hasFocus).name
if (-not $current -or $current -eq $Name) { exit 0 }

function Rename([string]$from, [string]$to) {
    & $cli command update-workspace-config --workspace $from --name $to | Out-Null
}

if ($workspaces.name -contains $Name) {
    $tmp = 'swap-tmp'
    Rename $Name $tmp
    Rename $current $Name
    Rename $tmp $current
} else {
    Rename $current $Name
}
