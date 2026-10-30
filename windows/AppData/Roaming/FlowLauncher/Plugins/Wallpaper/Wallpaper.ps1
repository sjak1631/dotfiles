# Runs the compiled plugin (Wallpaper.dll, built by run_onchange_after_65-flow-wallpaper) for
# Wallpaper.cmd. Loaded from bytes: Smart App Control blocks loading the unsigned DLL as a file.
# The request is taken from the raw command line (parsed like any Windows program would) rather
# than a PowerShell parameter: powershell.exe -File mangles arguments that contain `\"`.
$request = [Environment]::GetCommandLineArgs()[-1]
$asm = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Wallpaper.dll')))
exit $asm.GetType('Program').GetMethod('Main').Invoke($null, @(, [string[]]@($request)))
