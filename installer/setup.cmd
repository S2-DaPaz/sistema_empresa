@echo off
setlocal
set "appdir=%~dp0"
if "%appdir:~-1%"=="\" set "appdir=%appdir:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$shell = New-Object -ComObject WScript.Shell; " ^
  "$desktop = [Environment]::GetFolderPath('Desktop'); " ^
  "$programs = [Environment]::GetFolderPath('Programs'); " ^
  "$folder = Join-Path $programs 'RV Sistema Empresa'; " ^
  "New-Item -ItemType Directory -Force -Path $folder | Out-Null; " ^
  "$shortcut = $shell.CreateShortcut((Join-Path $desktop 'RV Sistema Empresa.lnk')); " ^
  "$shortcut.TargetPath = Join-Path '%appdir%' 'start.vbs'; " ^
  "$shortcut.WorkingDirectory = '%appdir%'; " ^
  "$shortcut.IconLocation = Join-Path '%appdir%' 'RV Sistema Empresa.exe'; " ^
  "$shortcut.Save(); " ^
  "$shortcut2 = $shell.CreateShortcut((Join-Path $folder 'RV Sistema Empresa.lnk')); " ^
  "$shortcut2.TargetPath = Join-Path '%appdir%' 'start.vbs'; " ^
  "$shortcut2.WorkingDirectory = '%appdir%'; " ^
  "$shortcut2.IconLocation = Join-Path '%appdir%' 'RV Sistema Empresa.exe'; " ^
  "$shortcut2.Save();"

echo Instalacao concluida.
exit /b 0
