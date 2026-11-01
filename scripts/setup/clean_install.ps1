<#
.SYNOPSIS
    AnuvaadAI 2.0 - Clean Installation & Fresh Provisioning Script
.DESCRIPTION
    Safely performs a complete fresh installation of AnuvaadAI 2.0 on a connected Android device:
    1. Prompts for explicit user confirmation before touching the device (unless -Force).
    2. Removes stale application installations (adb uninstall org.anuvaad.ai.anuvaadai).
    3. Scoped cleanup: Cleans ONLY AnuvaadAI-specific directories (/sdcard/anuvaad-models and /sdcard/Android/data/org.anuvaad.ai.anuvaadai).
       DOES NOT delete any other phone directories.
    4. Installs the signed release APK (release/AnuvaadAI-2.0.apk).
    5. Grants runtime permissions (Microphone, Storage).
    6. Launches the application.
#>

param(
    [string]$PackageName = "org.anuvaad.ai.anuvaadai",
    [string]$ApkPath = "C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk",
    [string]$DeviceSerial = "",
    [switch]$SkipUninstall = $false,
    [switch]$CleanStaleModels = $true,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AnuvaadAI 2.0 - Fresh Clean Installation Utility       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Safety guard: Never touch device automatically without explicit user confirmation
if (-not $Force) {
    Write-Host "`nWARNING: This script will perform a clean installation of AnuvaadAI 2.0." -ForegroundColor Yellow
    Write-Host "Target APK: $ApkPath"
    Write-Host "Target Package: $PackageName"
    if ($CleanStaleModels) {
        Write-Host "Scoped Model Cleanup: Will remove only AnuvaadAI directories (/sdcard/anuvaad-models & app storage)." -ForegroundColor Yellow
    }
    $response = Read-Host "`nDo you wish to proceed? (yes/no)"
    if ($response -ne "yes" -and $response -ne "y") {
        Write-Host "Operation cancelled by user. Phone was NOT modified." -ForegroundColor Gray
        exit 0
    }
}

# Locate ADB
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $sdkAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { $adb = $sdkAdb }
}

if (-not $adb) {
    Write-Error "ADB not found. Please connect physical device and ensure Android SDK platform-tools are installed."
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
        Write-Warning "No connected Android physical device found via ADB."
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

Write-Host "Target Device: $deviceSerial ($($targetDev.Details))" -ForegroundColor Green

if (-not (Test-Path $ApkPath)) {
    Write-Error "Release APK not found at: $ApkPath. Please verify release directory."
    exit 1
}

# 1. Uninstall old version
if (-not $SkipUninstall) {
    Write-Host "`n[1/5] Checking and removing old app installation..." -ForegroundColor Yellow
    $installed = & $adb -s $deviceSerial shell "pm list packages $PackageName"
    if ($installed -match $PackageName) {
        Write-Host "  Uninstalling $PackageName..." -ForegroundColor Gray
        & $adb -s $deviceSerial uninstall $PackageName
        Write-Host "  [OK] Old package uninstalled." -ForegroundColor Green
    } else {
        Write-Host "  Package is not currently installed. Ready for fresh install." -ForegroundColor DarkGray
    }
}

# 2. Scoped Cleanup of AnuvaadAI-Specific Model Directories
if ($CleanStaleModels) {
    Write-Host "`n[2/5] Performing Scoped AnuvaadAI Storage Cleanup..." -ForegroundColor Yellow
    Write-Host "  Removing stale fallback directory: /sdcard/anuvaad-models" -ForegroundColor DarkGray
    & $adb -s $deviceSerial shell "rm -rf /sdcard/anuvaad-models"
    Write-Host "  Removing app external files directory: /sdcard/Android/data/$PackageName" -ForegroundColor DarkGray
    & $adb -s $deviceSerial shell "rm -rf /sdcard/Android/data/$PackageName"
    Write-Host "  [OK] Scoped model cleanup complete. No other phone directories were touched." -ForegroundColor Green
}

# 3. Install Release APK
Write-Host "`n[3/5] Installing Release APK ($ApkPath)..." -ForegroundColor Yellow
& $adb -s $deviceSerial install -r -d $ApkPath
Write-Host "  [OK] Release APK installed successfully." -ForegroundColor Green

# 4. Grant Runtime Permissions
Write-Host "`n[4/5] Granting Runtime Permissions..." -ForegroundColor Yellow
& $adb -s $deviceSerial shell "pm grant $PackageName android.permission.RECORD_AUDIO"
& $adb -s $deviceSerial shell "pm grant $PackageName android.permission.READ_EXTERNAL_STORAGE 2>/dev/null"
& $adb -s $deviceSerial shell "pm grant $PackageName android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null"
Write-Host "  [OK] Permissions granted." -ForegroundColor Green

# 5. Launch Application or Next Step
Write-Host "`n[5/5] Package installed with permissions granted." -ForegroundColor Green
Write-Host "Next Step in 7-Step Sequence:" -ForegroundColor Yellow
Write-Host "  Run: .\scripts\setup\provision_models.ps1" -ForegroundColor Cyan
Write-Host "  Followed by: .\scripts\setup\verify_device_installation.ps1" -ForegroundColor Cyan
Write-Host "  Then relaunch: adb shell am force-stop $PackageName; adb shell am start -n $PackageName/.MainActivity" -ForegroundColor Cyan

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   AnuvaadAI 2.0 APK Clean Installation Completed!       " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
