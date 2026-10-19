$ErrorActionPreference = 'Stop'

# Turns off unwanted startup apps the same way Task Manager's "Startup apps" does
# (StartupApproved, first byte 03 = disabled). Apps re-adding their Run entry don't undo it.
# Runs on every apply: apps register themselves on first launch, after the first apply.
$unwanted = @(
    '^OneDrive$'
    '^com\.squirrel\.slack\.'
    '^Steam$'
    '^(HoYoPlay|HYP)'
    '^Spotify$'
    'Bitwarden'
    '^MicrosoftEdgeAutoLaunch_'
)

$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
if (-not (Test-Path $approved)) { New-Item $approved -Force | Out-Null }
$approvedKey = Get-Item $approved

foreach ($name in (Get-Item $run).GetValueNames()) {
    if (-not ($unwanted | Where-Object { $name -match $_ })) { continue }
    $current = $approvedKey.GetValue($name)
    if ($current -and $current[0] -eq 3) { continue }  # already disabled
    $disabled = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()))
    Set-ItemProperty $approved -Name $name -Value $disabled -Type Binary
    Write-Host "==> startup app disabled: $name"
}
# (Edge's "startup boost" policy lives under HKCU\Software\Policies, which needs admin; not set)
