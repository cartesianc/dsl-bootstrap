@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0render-ast.ps1" %*
