@echo off
setlocal

echo Encerrando processos...
taskkill /f /im "RV Sistema Empresa.exe" >nul 2>&1

set "appData=%APPDATA%"
set "localApp=%LOCALAPPDATA%"
set "appName=RV Sistema Empresa"

set "dirRoaming=%appData%\%appName%"
set "dirLocal=%localApp%\%appName%"

echo Removendo atalhos...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$shell = New-Object -ComObject WScript.Shell; " ^
  "$desktop = [Environment]::GetFolderPath('Desktop'); " ^
  "$programs = [Environment]::GetFolderPath('Programs'); " ^
  "$shortcut1 = Join-Path $desktop 'RV Sistema Empresa.lnk'; " ^
  "$shortcut2 = Join-Path (Join-Path $programs 'RV Sistema Empresa') 'RV Sistema Empresa.lnk'; " ^
  "if (Test-Path $shortcut1) { Remove-Item $shortcut1 -Force }; " ^
  "if (Test-Path $shortcut2) { Remove-Item $shortcut2 -Force }; " ^
  "$folder = Join-Path $programs 'RV Sistema Empresa'; " ^
  "if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }"

echo Removendo arquivos...
if exist "%dirRoaming%" rmdir /s /q "%dirRoaming%"
if exist "%dirLocal%" rmdir /s /q "%dirLocal%"

echo Desinstalacao concluida.
pause
exit /b 0
