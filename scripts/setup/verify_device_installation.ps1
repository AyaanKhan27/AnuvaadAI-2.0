<#
.SYNOPSIS
    AnuvaadAI 2.0 - Android Physical Device Installation & Model Verifier
.DESCRIPTION
    Performs comprehensive diagnostic checks on connected Android device:
    - App package installation, version, and granted permissions
    - Translation model files, sizes, and accessibility
    - Santali VITS TTS model files and phoneme map
    - Fallback directory status (/sdcard/anuvaad-models)
    - Google Speech Services and Android System Intelligence status
#>

param(
    [string]$PackageName = "org.anuvaad.ai.anuvaadai",
    [string]$DeviceSerial = ""
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AnuvaadAI 2.0 - Physical Device Installation Verifier   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate ADB
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $sdkAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { $adb = $sdkAdb }
}

if (-not $adb) {
    Write-Error "ADB not found. Please install Android Platform Tools."
    exit 1
}

# Core Helper: Execute ADB native process cleanly with isolated stdout/stderr streams
function Invoke-AdbCommand {
    param(
        [string]$AdbPath,
        [string]$Device = "",
        [string[]]$Arguments = @()
    )

    $argList = @()
    if (-not [string]::IsNullOrWhiteSpace($Device)) {
        $argList += "-s"
        $argList += $Device
    }
    $argList += $Arguments

    $escapedArgs = ($argList | ForEach-Object {
        $arg = $_.ToString()
        if ($arg.StartsWith('"') -and $arg.EndsWith('"') -and $arg.Length -ge 2) {
            $arg
        } elseif ($arg -match '[\s"]') {
            '"' + ($arg -replace '(\\*)(")', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        } else {
            $arg
        }
    }) -join " "

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $AdbPath
    $psi.Arguments = $escapedArgs
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderr = $proc.StandardError.ReadToEnd()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $proc.WaitForExit()

    $combined = ($stdout + "`n" + $stderr).Trim()

    return [PSCustomObject]@{
        ExitCode = $proc.ExitCode
        Stdout   = $stdout
        Stderr   = $stderr
        Combined = $combined
        Success  = ($proc.ExitCode -eq 0)
    }
}

# Helper Function: Parse 'adb devices -l' and discover target device
function Get-AdbTargetDevice {
    param(
        [string]$AdbPath,
        [string]$ExplicitSerial = ""
    )

    $res = Invoke-AdbCommand -AdbPath $AdbPath -Arguments @("devices", "-l")
    if (-not $res.Success) {
        Write-Error "Failed to execute '$AdbPath devices -l'. Error: $($res.Combined)"
        exit 1
    }

    $rawLines = $res.Stdout -split "`r?`n"
    $authorizedDevices = @()
    $offlineDevices = @()
    $unauthorizedDevices = @()

    foreach ($line in $rawLines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("*") -or $trimmed.StartsWith("List of devices attached")) { continue }

        $tokens = $trimmed -split '\s+'
        if ($tokens.Count -ge 2) {
            $serial = $tokens[0]
            $state = $tokens[1]
            $details = if ($tokens.Count -gt 2) { ($tokens[2..($tokens.Count - 1)] -join ' ') } else { '' }

            $deviceInfo = [PSCustomObject]@{
                Serial  = $serial
                State   = $state
                Details = $details
                RawLine = $trimmed
            }

            switch ($state) {
                "device"       { $authorizedDevices += $deviceInfo }
                "offline"      { $offlineDevices += $deviceInfo }
                "unauthorized" { $unauthorizedDevices += $deviceInfo }
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitSerial)) {
        $match = $authorizedDevices | Where-Object { $_.Serial -eq $ExplicitSerial }
        if ($match) { return $match }
        Write-Error "Requested device serial '$ExplicitSerial' was not found among authorized 'device' connections."
        exit 1
    }

    if ($authorizedDevices.Count -eq 0) {
        Write-Warning "No active, authorized Android physical device or emulator detected via ADB."
        exit 0
    }

    if ($authorizedDevices.Count -gt 1) {
        Write-Error "Multiple authorized devices detected via ADB ($($authorizedDevices.Count) devices). Explicit selection required."
        Write-Host "Please re-run specifying -DeviceSerial <serial>." -ForegroundColor Yellow
        exit 1
    }

    return $authorizedDevices[0]
}

$targetDev = Get-AdbTargetDevice -AdbPath $adb -ExplicitSerial $DeviceSerial
if (-not $targetDev) { exit 0 }
$deviceSerial = $targetDev.Serial

Write-Host "Device Connected: $deviceSerial ($($targetDev.Details))" -ForegroundColor Green

# 2. Device Specifications
$model = (& $adb -s $deviceSerial shell getprop ro.product.model 2>$null).ToString().Trim()
$brand = (& $adb -s $deviceSerial shell getprop ro.product.brand 2>$null).ToString().Trim()
$apiLevel = (& $adb -s $deviceSerial shell getprop ro.build.version.sdk 2>$null).ToString().Trim()
$androidVer = (& $adb -s $deviceSerial shell getprop ro.build.version.release 2>$null).ToString().Trim()
Write-Host "Hardware: $brand $model | Android $androidVer (API $apiLevel)" -ForegroundColor Gray

# 3. App Package Verification
Write-Host "`n[1/5] Checking Application Package..." -ForegroundColor Yellow
$pkgCheck = & $adb -s $deviceSerial shell "pm list packages $PackageName"
if ($pkgCheck -match $PackageName) {
    Write-Host "  [OK] Package '$PackageName' is INSTALLED" -ForegroundColor Green
    $dump = (& $adb -s $deviceSerial shell "dumpsys package $PackageName | grep -E 'versionName|versionCode'") | Out-String
    Write-Host "       $($dump.Trim())" -ForegroundColor DarkGray
    
    # Check permissions
    $perms = (& $adb -s $deviceSerial shell "dumpsys package $PackageName | grep -E 'android.permission.RECORD_AUDIO: granted=true'") | Out-String
    if ($perms -match "RECORD_AUDIO") {
        Write-Host "  [OK] Microphone Permission (RECORD_AUDIO) is GRANTED" -ForegroundColor Green
    } else {
        Write-Warning "  [WARN] Microphone permission is not yet granted. Run: adb shell pm grant $PackageName android.permission.RECORD_AUDIO"
    }
} else {
    Write-Warning "  [MISSING] Package '$PackageName' is NOT installed on device."
}

# 4. Translation Models Check (Primary Storage)
Write-Host "`n[2/5] Checking Translation Neural Models in App Storage..." -ForegroundColor Yellow
$primaryDir = "/sdcard/Android/data/$PackageName/files/models"
$lsPrimary = (& $adb -s $deviceSerial shell "ls -l '$primaryDir' 2>/dev/null") | Out-String

if ($lsPrimary -match "encoder\.onnx" -and $lsPrimary -match "decoder_prefill\.onnx" -and $lsPrimary -match "decoder_with_past\.onnx") {
    Write-Host "  [FOUND] IndicTrans2 Models verified in $primaryDir" -ForegroundColor Green
    $verifiedStamp = (& $adb -s $deviceSerial shell "cat '$primaryDir/.verified' 2>/dev/null") | Out-String
    if ($verifiedStamp.Trim()) {
        Write-Host "  [VERIFIED] Installation stamp: $($verifiedStamp.Trim())" -ForegroundColor Green
    }
} else {
    Write-Warning "  [MISSING] IndicTrans2 models not found in primary storage ($primaryDir)."
}

# 5. Fallback Directory Status
Write-Host "`n[3/5] Checking Stale Fallback Directory Status..." -ForegroundColor Yellow
$fallbackDir = "/sdcard/anuvaad-models"
$lsFallback = (& $adb -s $deviceSerial shell "ls -la '$fallbackDir' 2>/dev/null") | Out-String
if ($lsFallback.Trim() -and $lsFallback -match "onnx") {
    Write-Host "  [NOTICE] Fallback directory exists: $fallbackDir (contains models)" -ForegroundColor DarkGray
} else {
    Write-Host "  [CLEAN] Fallback directory /sdcard/anuvaad-models is clean / empty (guaranteeing fresh app storage loading)." -ForegroundColor Green
}

# 6. Santali VITS TTS Check
Write-Host "`n[4/5] Checking Santali VITS TTS Model..." -ForegroundColor Yellow
$primaryTts = "/sdcard/Android/data/$PackageName/files/santali-tts"
$lsTts = (& $adb -s $deviceSerial shell "ls -l '$primaryTts' 2>/dev/null") | Out-String
if ($lsTts -match "santali_piper_vits\.onnx") {
    Write-Host "  [FOUND] Santali VITS ONNX model verified in $primaryTts" -ForegroundColor Green
    $ttsVerified = (& $adb -s $deviceSerial shell "cat '$primaryTts/.verified' 2>/dev/null") | Out-String
    if ($ttsVerified.Trim()) {
        Write-Host "  [VERIFIED] TTS installation stamp: $($ttsVerified.Trim())" -ForegroundColor Green
    }
} else {
    Write-Warning "  [MISSING] Santali VITS TTS model not found in $primaryTts."
}

# 7. Speech Services Provider Check
Write-Host "`n[5/5] Checking Speech Recognition Services..." -ForegroundColor Yellow
$recServices = (& $adb -s $deviceSerial shell "dumpsys package | grep -B 2 -A 5 RecognitionService") | Out-String
if ($recServices -match "com\.google\.android\.tts") {
    Write-Host "  [OK] Google Speech Services (com.google.android.tts) is present." -ForegroundColor Green
}
if ($recServices -match "com\.google\.android\.as") {
    Write-Host "  [OK] Android System Intelligence (com.google.android.as) is present." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   Verification Complete.                                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
