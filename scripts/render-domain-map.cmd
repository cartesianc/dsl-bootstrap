@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0render-domain-map.ps1" %*
