@echo off
rem Re-applies GlazeWM's layout a little after a window appeared. Run from a GlazeWM window rule
rem (on: manage) inside `conhost --headless`.
rem Zen (Firefox) restores its last size/position on startup *after* GlazeWM has tiled it, so it
rem ends up overlapping the other window; a redraw puts it back where GlazeWM wants it.
rem (ping is the delay: timeout needs console input, which a headless console doesn't have)
setlocal
set glazewm="%ProgramFiles%\glzr.io\GlazeWM\cli\glazewm.exe"
ping -n 2 127.0.0.1 >nul
%glazewm% command wm-redraw >nul 2>&1
ping -n 3 127.0.0.1 >nul
%glazewm% command wm-redraw >nul 2>&1
