param([string]$Device = '', [switch]$Emulator, [switch]$Rebuild)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:ANDROID_HOME = 'D:\AndroidSDK'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_AVD_HOME = 'D:\AndroidAVDs'
$env:GRADLE_USER_HOME = 'D:\GradleHome'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
if ($Emulator) {
    $devices = & $adb devices
    $running = @($devices | Where-Object { $_ -match '^emulator-\d+\s+device$' })
    if ($running.Count -gt 0) {
        $Device = ($running[0] -split '\s+')[0]
    } else {
        $Device = 'emulator-5554'
        Start-Process -FilePath (Join-Path $env:ANDROID_HOME 'emulator\emulator.exe') -ArgumentList '-avd', 'FitTrack_API29', '-port', '5554', '-gpu', 'swiftshader_indirect', '-memory', '1024', '-cores', '2', '-no-boot-anim', '-no-snapshot', '-camera-back', 'webcam0', '-camera-front', 'none' -WindowStyle Normal
        Write-Host 'Demarrage Android...'
        & $adb -s $Device wait-for-device
    }
    $booted = $false
    for ($attempt = 0; $attempt -lt 180; $attempt++) {
        $bootState = & $adb -s $Device shell getprop sys.boot_completed
        if ($bootState -match '1') { $booted = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $booted) { throw 'Android ne demarre pas. Fermez des applications ou utilisez un telephone USB.' }
}
if (-not $Device) {
    $connected = @(& $adb devices | Where-Object { $_ -match '^\S+\s+device$' })
    if ($connected.Count -ne 1) {
        & $adb devices
        throw 'Branchez un telephone Android avec debogage USB, ou lancez : .\scripts\run-android.ps1 -Emulator'
    }
    $Device = ($connected[0] -split '\s+')[0]
}
$apk = Join-Path (Split-Path $PSScriptRoot -Parent) 'build\app\outputs\apk\debug\app-debug.apk'
if ($Emulator -and (-not $Rebuild) -and (Test-Path -LiteralPath $apk)) {
    & $adb -s $Device install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'Installation Android echouee.' }
    & $adb -s $Device shell am force-stop 'tn.esprit.fittrack_ai'
    & $adb -s $Device shell am start -n 'tn.esprit.fittrack_ai/.MainActivity' --ez enable-impeller false
} else {
    if ($Emulator) { flutter run -d $Device --no-enable-impeller } else { flutter run -d $Device }
}
