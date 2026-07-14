@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File; Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force; & '%~dp0scripts\Setup.ps1'"
pause
