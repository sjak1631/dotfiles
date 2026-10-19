$ErrorActionPreference = 'Stop'

# Quieter Windows: no system nags at logon. App notifications (Slack etc.) are left alone.
function Set-Dword([string]$path, [string]$name, [int]$value) {
    if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
    Set-ItemProperty $path -Name $name -Value $value -Type DWord
}

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-Dword $cdm 'SubscribedContent-338389Enabled' 0   # tips, tricks and suggestions
Set-Dword $cdm 'SubscribedContent-310093Enabled' 0   # Windows welcome experience after updates
Set-Dword $cdm 'SubscribedContent-353698Enabled' 0   # suggested content in Settings
Set-Dword $cdm 'SoftLandingEnabled' 0                # "get the most out of Windows" tips
Set-Dword $cdm 'SystemPaneSuggestionsEnabled' 0      # suggestions in Start

# "Finish setting up your device" screen
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0

# Toast whenever an app registers itself to run at startup (Steam, Slack, Spotify, ...)
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp' 'Enabled' 0

Write-Host '==> Windows tips, suggestions and startup-app toasts turned off'
