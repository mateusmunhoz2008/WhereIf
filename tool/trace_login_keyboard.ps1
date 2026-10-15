param(
    [string]$Device = 'RQCX406HKYE'
)

$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw 'ADB nao encontrado. Confira a instalacao do Android SDK.'
}

# Filter by the running app, never by keyboard text or account information.
$appProcessId = [string](& $adbPath -s $Device shell pidof com.example.autth_injustice_app)
$appProcessId = $appProcessId.Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($appProcessId)) {
    throw 'Abra o app no celular antes de iniciar a captura. Confira tambem a depuracao USB.'
}
if ($appProcessId -notmatch '^\d+$') {
    throw 'Nao foi possivel identificar um unico processo do app.'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot 'build\login-keyboard-logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$logPath = Join-Path $logDirectory ('login-ime-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Write-Host "Capturando o teclado do app. Reproduza o abre/fecha rapido; termine com Ctrl+C."
Write-Host "Arquivo para enviar: $logPath"
Write-Host 'Se fechar/reiniciar o app, execute este comando novamente.'

& $adbPath -s $Device logcat --pid=$appProcessId -T 1 -v threadtime 'flutter:I' 'ImeTracker:V' 'InsetsController:V' 'InputMethodManager:V' '*:S' |
    Where-Object { $_ -match 'LOGIN_IME|ImeTracker|InsetsController|InputMethodManager' } |
    Tee-Object -FilePath $logPath
