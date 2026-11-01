<#
.SYNOPSIS
    AnuvaadAI 2.0 - High-Speed Model Provisioning & Cryptographic Verification Script
.DESCRIPTION
    Provisions all 19 offline AI neural model files (IndicTrans2 Indic-Indic, English-Indic,
    and Santali Piper VITS TTS) to physical Android devices (OPPO CPH2793IN / Realme Narzo N55) via ADB.
    Features:
    - Robust native process execution (Invoke-AdbCommand) with separated stdout and stderr streams.
    - True exit code ($LASTEXITCODE / ExitCode) evaluation, eliminating PowerShell NativeCommandError on stderr progress.
    - Robust ADB device detection parsing 'adb devices -l' with authorized device filtering.
    - Pre-flight storage space validation before any cleanup or transfers.
    - Scoped cleanup of stale fallback directories (/sdcard/anuvaad-models).
    - Idempotency with exact byte-size verification.
    - Destination SHA-256 calculation on-device using sha256sum (with temp-pull fallback).
    - Individual PASS/FAIL verification against official reference SHA-256 manifests.
    - Strict error handling with immediate failure halt on checksum mismatch or ADB failure.
    - Automated cleanup of temporary verification files.
#>

param(
    [string]$PackageName = "org.anuvaad.ai.anuvaadai",
    [string]$SourceRoot = "C:\AnuvaadAI Anti",
    [string]$IndicSource = "C:\AnuvaadAI2\anuvaad-models",
    [string]$EnIndicSource = "C:\AnuvaadAI2\en-indic-models",
    [string]$IndicEnSource = "C:\AnuvaadAI Anti\indic-en-models",
    [string]$DeviceSerial = "",
    [switch]$CleanFallbackDirectory = $false,
    [switch]$ForceReupload = $false,
    [switch]$IncludeIndicEn = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AnuvaadAI 2.0 - Neural Model Provisioning & SHA-256    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Official Reference Manifest for All 19 Model Files
$ReferenceHashes = @{
    # Santali Piper VITS TTS
    "santali_piper_vits.onnx"       = "4b77ff657567a9163f99e7128fd832e2db95bba1aedf44310e6e60ebf3c11970"
    "santali_piper_vits.onnx.json"  = "797c728eba439d35967cc8d03c52d53c53a03e5f436c2847e02f037765fd4371"
    "phoneme_id_map.json"           = "aaeaf4a2eedb9ae38d65b334178694ddbda337235c52771b267d1b73728db501"

    # IndicTrans2 Indic-to-Indic
    "encoder.onnx"                  = "c7bb33c86d57f54f3d784e634e93e7559fd1a246ab2d0fe4b74395d2e964afe9"
    "decoder_prefill.onnx"          = "87cc453cb3224ee6716f98ef6b7fe402454272bf23b884f2db63551f2bdd1106"
    "decoder_with_past.onnx"        = "355b0becb7d5d4063ed6b6c00b366cd22f60c1c60ed857149bdd7d7cd6931ba9"
    "model.SRC"                     = "ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4"
    "model.TGT"                     = "ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4"
    "dict.SRC.json"                 = "3d3b180702520742dec423a5a7f7b4e3dad399d69e40ca7df294a1567884bed5"
    "dict.TGT.json"                 = "f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146"

    # IndicTrans2 English-to-Indic
    "encoder_model.onnx"            = "6da8412b812868e3b65a67036f3290c5ca5bc160a06d05e67886e0ff28557bce"
    "encoder_model.onnx.data"       = "b093e2fb820ada91812eaa1231eaa98c087d4b00240edd3bac4eaaabfa04cece"
    "decoder_model.onnx"            = "ad60b1ee386c7aaf537f34fb3885824705f1c2133670e9a5720ac47640778775"
    "decoder_with_past_model.onnx"  = "2ab43e849050ae0ec10d10c9a51fb7f49b0066fa21c9d3ef532f3607e153f3ae"
    "decoder_shared.onnx.data"      = "89982fdde643782af31c9305446f1e05a896320003720da6b85737489b95fd5d"
    "en_model.SRC"                  = "3cedc5cbcc740369b76201942a0f096fec7287fee039b55bdb956f301235b914"
    "en_model.TGT"                  = "ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4"
    "en_dict.SRC.json"              = "c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689"
    "en_dict.TGT.json"              = "f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146"

    # IndicTrans2 Indic-to-English (distilled 200M INT8)
    "ie_encoder_model.onnx"            = "79dd1c3d9f90f8bbd48effcc2d150616ac3a97525c8081481f14cd5095567ca6"
    "ie_encoder_model.onnx.data"       = "6c402df00dfc45a69607e0231e1e5fd884508b19ca664836c94dd61bfa1ba137"
    "ie_decoder_model.onnx"            = "845cdbaf0ee97d3c8ddff249a2e2d6e475d7ae1781157fcc6d0d651405bb8dd6"
    "ie_decoder_with_past_model.onnx"  = "bcc818db56bc681fab2d50ca31b99dbcb5f82abbce4dccc92946edf5906fa86e"
    "ie_decoder_shared.onnx.data"      = "abe939ce4d60bcbb9744790640188686c8af084083eb50d63bdbb7266a325d9a"
    "ie_model.SRC"                     = "ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4"
    "ie_model.TGT"                     = "3cedc5cbcc740369b76201942a0f096fec7287fee039b55bdb956f301235b914"
    "ie_dict.SRC.json"                 = "3d3b180702520742dec423a5a7f7b4e3dad399d69e40ca7df294a1567884bed5"
    "ie_dict.TGT.json"                 = "13c3a162fe655dbe99c790a413675c5d0634cd771fadcefe8d407676a7d1a311"
    "ie_tokenizer_config.json"        = "b0c7ac8aeb57d54d079494ce726563cc37398e698086104bd06b5aa5b69a775d"
    "ie_generation_config.json"       = "6c8b29ae72e680d5a2d9e849567f6f556d3f4e9bbd42434964a646f49b556972"
}

# 1. Locate ADB
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $sdkAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { $adb = $sdkAdb }
}

if (-not $adb) {
    Write-Error "ADB not found in PATH or standard Android SDK location."
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

    # Format arguments for ProcessStartInfo
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

    $exitCode = $proc.ExitCode
    $combined = ($stdout + "`n" + $stderr).Trim()

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Stdout   = $stdout
        Stderr   = $stderr
        Combined = $combined
        Success  = ($exitCode -eq 0)
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
    $otherDevices = @()

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
                default        { $otherDevices += $deviceInfo }
            }
        }
    }

    # If explicit serial requested by user
    if (-not [string]::IsNullOrWhiteSpace($ExplicitSerial)) {
        $match = $authorizedDevices | Where-Object { $_.Serial -eq $ExplicitSerial }
        if ($match) {
            return $match
        } else {
            Write-Error "Requested device serial '$ExplicitSerial' was not found among authorized 'device' connections."
            if ($authorizedDevices.Count -gt 0) {
                Write-Host "`nAvailable authorized devices:" -ForegroundColor Yellow
                foreach ($dev in $authorizedDevices) {
                    Write-Host "  - $($dev.Serial) [$($dev.Details)]" -ForegroundColor Gray
                }
            }
            if ($unauthorizedDevices.Count -gt 0) {
                Write-Host "`nUnauthorized devices (check phone screen for USB debugging prompt):" -ForegroundColor Red
                foreach ($dev in $unauthorizedDevices) {
                    Write-Host "  - $($dev.Serial)" -ForegroundColor Red
                }
            }
            exit 1
        }
    }

    # Auto-detection validation
    if ($authorizedDevices.Count -eq 0) {
        $errMsg = "No active, authorized Android physical device or emulator detected via ADB."
        if ($unauthorizedDevices.Count -gt 0) {
            $errMsg += "`nFound unauthorized device(s): " + (($unauthorizedDevices | ForEach-Object { "$($_.Serial) (Please unlock phone and accept 'Allow USB debugging')" }) -join ", ")
        }
        if ($offlineDevices.Count -gt 0) {
            $errMsg += "`nFound offline device(s): " + (($offlineDevices | ForEach-Object { "$($_.Serial) (Please reconnect USB cable or run 'adb kill-server')" }) -join ", ")
        }
        $errMsg += "`n`nTarget destination directories on device for manual transfer:"
        $errMsg += "`n  1. /sdcard/Android/data/$PackageName/files/models/"
        $errMsg += "`n  2. /sdcard/Android/data/$PackageName/files/en-indic-models/"
        $errMsg += "`n  3. /sdcard/Android/data/$PackageName/files/santali-tts/"
        Write-Error $errMsg
        exit 1
    }

    if ($authorizedDevices.Count -gt 1) {
        Write-Error "Multiple authorized devices detected via ADB ($($authorizedDevices.Count) devices). Explicit selection required."
        Write-Host "`nDetected authorized devices:" -ForegroundColor Yellow
        foreach ($dev in $authorizedDevices) {
            Write-Host "  - $($dev.Serial) [$($dev.Details)]" -ForegroundColor Cyan
        }
        Write-Host "`nPlease re-run specifying -DeviceSerial <serial>, e.g.:" -ForegroundColor Yellow
        Write-Host "  .\scripts\setup\provision_models.ps1 -DeviceSerial $($authorizedDevices[0].Serial)" -ForegroundColor Yellow
        exit 1
    }

    # Exactly one authorized device found
    return $authorizedDevices[0]
}

# 2. Select Device and Validate State
Write-Host "Detecting connected Android devices via $adb..." -ForegroundColor Gray
$targetDevObj = Get-AdbTargetDevice -AdbPath $adb -ExplicitSerial $DeviceSerial
$deviceSerial = $targetDevObj.Serial
$deviceDetails = $targetDevObj.Details

# Confirm device state using adb get-state
$stateRes = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("get-state")
$stateCheck = $stateRes.Stdout.Trim()
if (-not $stateRes.Success -or $stateCheck -ne "device") {
    Write-Error "Device $deviceSerial is not in ready 'device' state (Exit code: $($stateRes.ExitCode), State: '$stateCheck', Stderr: $($stateRes.Stderr.Trim()))."
    exit 1
}

# Query hardware properties
$brand = (Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "getprop", "ro.product.brand")).Stdout.Trim()
$model = (Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "getprop", "ro.product.model")).Stdout.Trim()
$androidVer = (Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "getprop", "ro.build.version.release")).Stdout.Trim()
$apiLevel = (Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "getprop", "ro.build.version.sdk")).Stdout.Trim()

Write-Host "Connected Device: $deviceSerial ($brand $model | Android $androidVer API $apiLevel)" -ForegroundColor Green

# 3. Storage Validation BEFORE Any Cleanup or Transfer
Write-Host "`n[1/6] Pre-Flight Storage Validation..." -ForegroundColor Yellow
$dfRes = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "df -k /sdcard | tail -n 1")
if (-not $dfRes.Success) {
    Write-Error "Failed to query storage space on device $deviceSerial (Exit code: $($dfRes.ExitCode)). Output: $($dfRes.Combined)"
    exit 1
}

$dfLine = $dfRes.Stdout.Trim()
$dfTokens = $dfLine -split '\s+'
if ($dfTokens.Count -lt 4) {
    Write-Error "Unable to parse storage output from device: $dfLine (Stderr: $($dfRes.Stderr.Trim()))"
    exit 1
}

$availKb = [double]$dfTokens[3]
$availGb = [math]::Round($availKb / 1024 / 1024, 2)
$minRequiredGb = if ($IncludeIndicEn) { 0.50 } else { 3.50 }

if ($availGb -lt $minRequiredGb) {
    Write-Error "Insufficient storage space on device $deviceSerial! Available: $availGb GB, Required: $minRequiredGb GB. Please free up space on device before provisioning."
    exit 1
}
Write-Host "  [PASS] Storage verified: $availGb GB available on /sdcard (Minimum required: $minRequiredGb GB)." -ForegroundColor Green

# 4. Scoped Cleanup of Stale Fallback Directory
if ($CleanFallbackDirectory) {
    Write-Host "`n[2/6] Scoped Cleanup: Removing /sdcard/anuvaad-models..." -ForegroundColor Yellow
    $rmRes = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "rm -rf /sdcard/anuvaad-models")
    if (-not $rmRes.Success) {
        Write-Error "Failed to clean fallback directory /sdcard/anuvaad-models on device $deviceSerial (Exit code: $($rmRes.ExitCode)). Output: $($rmRes.Combined)"
        exit 1
    }
    Write-Host "  [OK] Stale fallback directory removed. Clean installation guaranteed." -ForegroundColor Green
}

# 5. Target Directories Creation
$targetPrimary = "/sdcard/Android/data/$PackageName/files"
Write-Host "`n[3/6] Ensuring Primary Storage Directories Exist..." -ForegroundColor Yellow
if ($IncludeIndicEn) {
    # Targeted Indic-to-English mode: Only ensure indic-en-models directory exists
    $mkdirRes = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "mkdir -p $targetPrimary/indic-en-models")
    if (-not $mkdirRes.Success) {
        Write-Error "Failed to create target directory $targetPrimary/indic-en-models on device $deviceSerial (Exit code: $($mkdirRes.ExitCode)). Output: $($mkdirRes.Combined)"
        exit 1
    }
    # Enforce directory permissions 755 (drwxr-xr-x)
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "chmod 755 $targetPrimary/indic-en-models") | Out-Null
    Write-Host "  [OK] Target directory verified: $targetPrimary/indic-en-models (permissions: 755)" -ForegroundColor Green
} else {
    $mkdirRes = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "mkdir -p $targetPrimary/models $targetPrimary/en-indic-models $targetPrimary/santali-tts")
    if (-not $mkdirRes.Success) {
        Write-Error "Failed to create target directories on device $deviceSerial (Exit code: $($mkdirRes.ExitCode)). Output: $($mkdirRes.Combined)"
        exit 1
    }
    Write-Host "  [OK] Target directories verified: $targetPrimary" -ForegroundColor Green
}

# Helper function: Calculate Remote SHA-256 with Device sha256sum or fallback temp pull
function Get-RemoteSha256 {
    param(
        [string]$RemotePath,
        [string]$Device
    )

    # Attempt on-device toybox/sha256sum first
    $shaRes = Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("shell", "sha256sum '$RemotePath' 2>&1")
    $cleanOutput = $shaRes.Combined.Trim()

    # Immediate disconnect check
    if ($cleanOutput -match "error: device.*not found" -or $cleanOutput -match "error: device offline" -or $cleanOutput -match "error: closed") {
        Write-Error "Device $Device disconnected during SHA-256 calculation: $cleanOutput"
        exit 1
    }

    if ($cleanOutput -match "^([a-fA-F0-9]{64})\s+") {
        return $matches[1].ToLower()
    }

    # If file doesn't exist remotely
    if ($cleanOutput -match "No such file or directory") {
        return $null
    }

    # Fallback: pull temporarily to local TEMP and compute hash if on-device sha256sum command missing
    Write-Host "    (Notice: Device sha256sum unsupported, using temporary pull fallback)" -ForegroundColor DarkGray
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    try {
        $pullRes = Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("pull", $RemotePath, $tempFile)
        if (-not $pullRes.Success) {
            $pullErr = $pullRes.Combined
            if ($pullErr -match "error: device.*not found" -or $pullErr -match "error: device offline" -or $pullErr -match "error: closed") {
                Write-Error "Device $Device disconnected during fallback pull: $pullErr"
                exit 1
            }
            Write-Warning "Fallback pull failed for $($RemotePath): $pullErr"
            return $null
        }
        if (Test-Path $tempFile) {
            $hash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLower()
            return $hash
        }
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    return $null
}

# Helper function: Provision file with cryptographic SHA-256 verification
function Provision-And-VerifyFile {
    param(
        [string]$LocalPath,
        [string]$RemoteDir,
        [string]$Device,
        [string]$ManifestKey
    )

    if (-not (Test-Path $LocalPath)) {
        Write-Error "Source file missing: $LocalPath"
        exit 1
    }

    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    $localSize = (Get-Item $LocalPath).Length
    $remotePath = "$RemoteDir/$fileName"
    $expectedHash = $ReferenceHashes[$ManifestKey]

    if (-not $expectedHash) {
        Write-Error "No reference SHA-256 found in manifest for key: $ManifestKey"
        exit 1
    }

    # Check if file already exists remotely and matches size
    $needsPush = $true
    if (-not $ForceReupload) {
        $lsRes = Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("shell", "ls -l '$remotePath' 2>&1")
        $lsText = $lsRes.Combined.Trim()

        # Check for device disconnection
        if ($lsText -match "error: device.*not found" -or $lsText -match "error: device offline" -or $lsText -match "error: closed") {
            Write-Error "Device $Device disconnected during remote file check: $lsText"
            exit 1
        }

        if ($lsRes.Success -and $lsText -match "$localSize") {
            # Destination has correct byte size, verify remote SHA-256
            $destHash = Get-RemoteSha256 -RemotePath $remotePath -Device $Device
            if ($destHash -and $destHash -eq $expectedHash) {
                if ($RemoteDir -match "indic-en-models") {
                    Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("shell", "chmod 644 '$remotePath'") | Out-Null
                }
                Write-Host "  [PASS] $fileName verified on device (SHA-256: $destHash)" -ForegroundColor Green
                $needsPush = $false
            } else {
                Write-Host "  [RELOAD] $fileName size matches but SHA-256 mismatch or unverified. Re-uploading..." -ForegroundColor Yellow
                $needsPush = $true
            }
        }
    }

    if ($needsPush) {
        Write-Host "  [PUSHING] $fileName ($([math]::Round($localSize / 1MB, 2)) MB) -> $RemoteDir..." -ForegroundColor Cyan
        
        # Execute push with robust process runner (isolated streams, exit code check)
        $pushRes = Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("push", $LocalPath, "$RemoteDir/")
        
        # ADB writes progress (e.g. "1 file pushed... 29.5 MB/s") to stderr even on success.
        # Check actual process exit code:
        if (-not $pushRes.Success) {
            Write-Error "  [FAIL] ADB push failed for $fileName on device $Device (Exit code: $($pushRes.ExitCode))! Details: $($pushRes.Combined)"
            exit 1
        }

        # Stderr contains progress info on success, display cleanly in log
        if (-not [string]::IsNullOrWhiteSpace($pushRes.Stderr)) {
            Write-Host "    $($pushRes.Stderr.Trim())" -ForegroundColor DarkGray
        }

        # Post-push cryptographic SHA-256 verification (ONLY executes after push succeeded!)
        Write-Host "    Verifying destination SHA-256 on device..." -ForegroundColor DarkGray
        $destHash = Get-RemoteSha256 -RemotePath $remotePath -Device $Device

        if ($destHash -and $destHash -eq $expectedHash) {
            if ($RemoteDir -match "indic-en-models") {
                Invoke-AdbCommand -AdbPath $adb -Device $Device -Arguments @("shell", "chmod 644 '$remotePath'") | Out-Null
            }
            Write-Host "  [PASS] $fileName transferred & verified (SHA-256: $destHash)" -ForegroundColor Green
        } else {
            Write-Error "  [FAIL] CHECKSUM MISMATCH on $fileName!`nExpected: $expectedHash`nActual:   $destHash`nStopping deployment immediately."
            exit 1
        }
    }
}

if ($IncludeIndicEn) {
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " [INDIC-TO-ENGLISH TARGETED MODE] Provisioning Indic-En   " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Existing 19 models in models/, en-indic-models/, santali-tts/ will remain 100% UNTOUCHED.`n" -ForegroundColor Green

    $indicEnMap = [ordered]@{
        "encoder_model.onnx"           = "ie_encoder_model.onnx"
        "encoder_model.onnx.data"      = "ie_encoder_model.onnx.data"
        "decoder_model.onnx"           = "ie_decoder_model.onnx"
        "decoder_with_past_model.onnx" = "ie_decoder_with_past_model.onnx"
        "decoder_shared.onnx.data"     = "ie_decoder_shared.onnx.data"
        "model.SRC"                    = "ie_model.SRC"
        "model.TGT"                    = "ie_model.TGT"
        "dict.SRC.json"                = "ie_dict.SRC.json"
        "dict.TGT.json"                = "ie_dict.TGT.json"
        "tokenizer_config.json"        = "ie_tokenizer_config.json"
        "generation_config.json"       = "ie_generation_config.json"
    }

    foreach ($entry in $indicEnMap.GetEnumerator()) {
        $f = $entry.Key
        $k = $entry.Value
        Provision-And-VerifyFile -LocalPath "$IndicEnSource\$f" -RemoteDir "$targetPrimary/indic-en-models" -Device $deviceSerial -ManifestKey $k
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $stampCmd = "echo 'verified_at=$timestamp; sha256_audit=PASS; serial=$deviceSerial' > $targetPrimary/indic-en-models/.verified"
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", $stampCmd) | Out-Null
    
    # Enforce POSIX permissions: 755 for directory, 644 for all files
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "chmod 755 $targetPrimary/indic-en-models") | Out-Null
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "chmod 644 $targetPrimary/indic-en-models/* $targetPrimary/indic-en-models/.verified") | Out-Null

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   ALL 11 INDIC-TO-ENGLISH MODEL FILES VERIFIED ON DEVICE!   " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    # 6. Provision Santali VITS TTS Models (3 files)
    Write-Host "`n[4/6] Provisioning & Verifying Santali VITS TTS Models..." -ForegroundColor Yellow
$ttsDir = "$SourceRoot\engines\speech_synthesis\models"
Provision-And-VerifyFile -LocalPath "$ttsDir\santali_piper_vits.onnx" -RemoteDir "$targetPrimary/santali-tts" -Device $deviceSerial -ManifestKey "santali_piper_vits.onnx"
Provision-And-VerifyFile -LocalPath "$ttsDir\santali_piper_vits.onnx.json" -RemoteDir "$targetPrimary/santali-tts" -Device $deviceSerial -ManifestKey "santali_piper_vits.onnx.json"
Provision-And-VerifyFile -LocalPath "$ttsDir\phoneme_id_map.json" -RemoteDir "$targetPrimary/santali-tts" -Device $deviceSerial -ManifestKey "phoneme_id_map.json"

# 7. Provision IndicTrans2 Indic-Indic Translation Models (7 files)
Write-Host "`n[5/6] Provisioning & Verifying IndicTrans2 Indic-Indic Models..." -ForegroundColor Yellow
$indicFiles = @(
    "encoder.onnx",
    "decoder_prefill.onnx",
    "decoder_with_past.onnx",
    "model.SRC",
    "model.TGT",
    "dict.SRC.json",
    "dict.TGT.json"
)
foreach ($f in $indicFiles) {
    Provision-And-VerifyFile -LocalPath "$IndicSource\$f" -RemoteDir "$targetPrimary/models" -Device $deviceSerial -ManifestKey $f
}

# 8. Provision IndicTrans2 English-to-Indic Translation Models (9 files)
Write-Host "`n[6/6] Provisioning & Verifying English-to-Indic Models..." -ForegroundColor Yellow
$enIndicMap = [ordered]@{
    "encoder_model.onnx"           = "encoder_model.onnx"
    "encoder_model.onnx.data"      = "encoder_model.onnx.data"
    "decoder_model.onnx"           = "decoder_model.onnx"
    "decoder_with_past_model.onnx" = "decoder_with_past_model.onnx"
    "decoder_shared.onnx.data"     = "decoder_shared.onnx.data"
    "model.SRC"                    = "en_model.SRC"
    "model.TGT"                    = "en_model.TGT"
    "dict.SRC.json"                = "en_dict.SRC.json"
    "dict.TGT.json"                = "en_dict.TGT.json"
}
foreach ($entry in $enIndicMap.GetEnumerator()) {
    $f = $entry.Key
    $k = $entry.Value
    Provision-And-VerifyFile -LocalPath "$EnIndicSource\$f" -RemoteDir "$targetPrimary/en-indic-models" -Device $deviceSerial -ManifestKey $k
}

# 9. Post-Provisioning Verified Stamp
Write-Host "`nWriting installation verification stamp on device..." -ForegroundColor Yellow
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$stampCmd1 = "echo 'verified_at=$timestamp; sha256_audit=PASS; serial=$deviceSerial' > $targetPrimary/models/.verified"
$stampRes1 = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", $stampCmd1)
if (-not $stampRes1.Success) {
    Write-Error "Failed to write verification stamp to $targetPrimary/models/.verified (Exit code: $($stampRes1.ExitCode)). Output: $($stampRes1.Combined)"
    exit 1
}

$stampCmd2 = "echo 'verified_at=$timestamp; sha256_audit=PASS; serial=$deviceSerial' > $targetPrimary/santali-tts/.verified"
$stampRes2 = Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", $stampCmd2)
if (-not $stampRes2.Success) {
    Write-Error "Failed to write verification stamp to $targetPrimary/santali-tts/.verified (Exit code: $($stampRes2.ExitCode)). Output: $($stampRes2.Combined)"
    exit 1
}

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   ALL 19 MODEL FILES TRANSFERRED & VERIFIED ON DEVICE!   " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
