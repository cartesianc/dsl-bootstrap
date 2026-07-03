@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-fast.ps1" %*
