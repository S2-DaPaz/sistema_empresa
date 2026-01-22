$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
$dist = Join-Path $root "dist\\installer"
$payloadDir = Join-Path $dist "payload"
$payloadFile = Join-Path $dist "payload.7z"
$sfxStub = "C:\\Program Files\\7-Zip\\7z.sfx"
$output = Join-Path $dist "RV Sistema Empresa Installer.exe"

if (!(Test-Path $sfxStub)) {
  throw "7z.sfx nao encontrado em $sfxStub"
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $payloadDir
New-Item -ItemType Directory -Force -Path $payloadDir | Out-Null

Copy-Item -Force (Join-Path $root "dist\\launcher\\RV Sistema Empresa.exe") $payloadDir
Copy-Item -Force (Join-Path $root "installer\\setup.cmd") $payloadDir
Copy-Item -Force (Join-Path $root "installer\\start.vbs") $payloadDir
Copy-Item -Force (Join-Path $root "installer\\README.txt") $payloadDir
Copy-Item -Recurse -Force (Join-Path $root "web\\dist") (Join-Path $payloadDir "web\\dist")

if (Test-Path $payloadFile) {
  Remove-Item -Force $payloadFile
}

& 7z a -t7z $payloadFile "$payloadDir\\*" | Out-Null

$config = Join-Path $root "installer\\config.txt"
cmd /c "copy /b `"$sfxStub`"+`"$config`"+`"$payloadFile`" `"$output`"" | Out-Null

Write-Host "Instalador criado em $output"
