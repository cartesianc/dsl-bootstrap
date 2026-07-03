@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-semantic.ps1" %*
