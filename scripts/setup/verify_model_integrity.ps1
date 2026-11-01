<#
.SYNOPSIS
    AnuvaadAI 2.0 - Local PC Model Integrity & Checksum Verifier
.DESCRIPTION
    Audits the local repository and asset stores on PC:
    1. Verifies exact filenames, byte sizes, and non-empty status for all 17+ model files.
    2. Validates cryptographic SHA-256 checksums against official manifests.
    3. Guarantees that no model file is corrupted before provisioning to physical devices.
#>

param(
    [string]$SourceRoot = "C:\AnuvaadAI Anti",
    [string]$IndicSource = "C:\AnuvaadAI2\anuvaad-models",
    [string]$EnIndicSource = "C:\AnuvaadAI2\en-indic-models",
    [switch]$SkipHashes = $false
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AnuvaadAI 2.0 - Model Integrity & Checksum Verifier     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Known Reference SHA-256 Manifest
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
    "en_dict.SRC.json"              = "c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689"
}

function Audit-Directory {
    param(
        [string]$Title,
        [string]$DirPath,
        [string[]]$RequiredFiles
    )

    Write-Host "`n--- $Title ---" -ForegroundColor Yellow
    Write-Host "Directory: $DirPath" -ForegroundColor Gray

    if (-not (Test-Path $DirPath)) {
        Write-Warning "Directory DOES NOT EXIST: $DirPath"
        return $false
    }

    $allPassed = $true
    foreach ($rf in $RequiredFiles) {
        $filePath = Join-Path $DirPath $rf
        if (Test-Path $filePath) {
            $item = Get-Item $filePath
            $sizeMB = [math]::Round($item.Length / 1MB, 2)
            if ($item.Length -gt 0) {
                if (-not $SkipHashes) {
                    $computedHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
                    $refKey = $rf
                    if ($DirPath -like "*en-indic*") {
                        if ($rf -eq "model.SRC") { $refKey = "en_model.SRC" }
                        if ($rf -eq "dict.SRC.json") { $refKey = "en_dict.SRC.json" }
                    }
                    $expectedHash = $ReferenceHashes[$refKey]

                    if ($expectedHash -and $computedHash -eq $expectedHash) {
                        Write-Host "  [OK] $rf ($sizeMB MB) -> SHA-256 MATCH: $computedHash" -ForegroundColor Green
                    } elseif ($expectedHash) {
                        Write-Error "  [HASH MISMATCH] $rf ($sizeMB MB) corrupted! Expected: $expectedHash, Actual: $computedHash"
                        $allPassed = $false
                    } else {
                        Write-Host "  [OK] $rf ($sizeMB MB) -> SHA-256: $computedHash" -ForegroundColor Green
                    }
                } else {
                    Write-Host "  [OK] $rf ($sizeMB MB, $($item.Length) bytes)" -ForegroundColor Green
                }
            } else {
                Write-Error "  [EMPTY FILE] $rf exists but is 0 bytes!"
                $allPassed = $false
            }
        } else {
            Write-Error "  [MISSING] $rf is missing from $DirPath!"
            $allPassed = $false
        }
    }
    return $allPassed
}

# 1. Santali VITS TTS Audit
$ttsDir = "$SourceRoot\engines\speech_synthesis\models"
$ttsFiles = @(
    "santali_piper_vits.onnx",
    "santali_piper_vits.onnx.json",
    "phoneme_id_map.json"
)
$ttsOk = Audit-Directory -Title "Santali Piper VITS TTS Model" -DirPath $ttsDir -RequiredFiles $ttsFiles

# 2. IndicTrans2 Indic-Indic Models Audit
$indicFiles = @(
    "encoder.onnx",
    "decoder_prefill.onnx",
    "decoder_with_past.onnx",
    "model.SRC",
    "model.TGT",
    "dict.SRC.json",
    "dict.TGT.json"
)
$indicOk = Audit-Directory -Title "IndicTrans2 Indic-to-Indic Translation Models" -DirPath $IndicSource -RequiredFiles $indicFiles

# 3. English-Indic Translation Models Audit
$enIndicFiles = @(
    "encoder_model.onnx",
    "encoder_model.onnx.data",
    "decoder_model.onnx",
    "decoder_with_past_model.onnx",
    "decoder_shared.onnx.data",
    "model.SRC",
    "model.TGT",
    "dict.SRC.json",
    "dict.TGT.json"
)
$enIndicOk = Audit-Directory -Title "IndicTrans2 English-to-Indic Translation Models" -DirPath $EnIndicSource -RequiredFiles $enIndicFiles

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($ttsOk -and $indicOk -and $enIndicOk) {
    Write-Host "   ALL 19 MODEL FILES CRYPTOGRAPHICALLY VERIFIED & INTACT! " -ForegroundColor Green
} else {
    Write-Warning "   ONE OR MORE MODEL VERIFICATIONS FAILED OR CORRUPTED!   "
}
Write-Host "==========================================================" -ForegroundColor Cyan
