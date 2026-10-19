@echo off
rem Starts GlazeWM (run by the dotfiles-glazewm logon task, inside `conhost --headless`).
rem Right after logon GlazeWM can crash while the desktop is still settling, so a crash
rem (non-zero exit) is retried up to 3 times. A normal exit (Alt+Shift+E) is not restarted.
rem `start /wait` goes through ShellExecute, which GlazeWM (a UIAccess program) needs.
setlocal
set tries=0
:launch
start "" /wait "%ProgramFiles%\glzr.io\GlazeWM\glazewm.exe"
if %errorlevel% equ 0 exit /b 0
set /a tries+=1
if %tries% geq 3 exit /b 1
rem ~2 s pause (timeout needs console input, which a headless console doesn't have)
ping -n 3 127.0.0.1 >nul
goto launch
