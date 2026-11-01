with open(r'C:\AnuvaadAI Anti\scripts\setup\provision_models.ps1', 'r', encoding='utf-8') as f:
    text = f.read()

# Add param
old_param = '''    [string]$DeviceSerial = "",
    [switch]$CleanFallbackDirectory = $true,
    [switch]$ForceReupload = $false'''

new_param = '''    [string]$IndicEnSource = "C:\\AnuvaadAI Anti\\indic-en-models",
    [string]$DeviceSerial = "",
    [switch]$CleanFallbackDirectory = $false,
    [switch]$ForceReupload = $false,
    [switch]$IncludeIndicEn = $false'''

text = text.replace(old_param, new_param)

# Add reference hashes
old_hashes = '''    "en_dict.SRC.json"              = "c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689"
    "en_dict.TGT.json"              = "f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146"
}'''

new_hashes = '''    "en_dict.SRC.json"              = "c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689"
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
}'''

text = text.replace(old_hashes, new_hashes)

# Add Indic-En section at end of script before final summary
indic_en_block = '''
# 9. Provision IndicTrans2 Indic-English Translation Models (9 files, optional switch)
if ($IncludeIndicEn) {
    Write-Host "`n[7/7] Provisioning & Verifying IndicTrans2 Indic-English Models..." -ForegroundColor Yellow
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "mkdir -p $targetPrimary/indic-en-models") | Out-Null
    Invoke-AdbCommand -AdbPath $adb -Device $deviceSerial -Arguments @("shell", "chmod -R 777 $targetPrimary/indic-en-models") | Out-Null

    $indicEnFiles = @(
        @{ Local = "encoder_model.onnx"; Key = "ie_encoder_model.onnx" },
        @{ Local = "encoder_model.onnx.data"; Key = "ie_encoder_model.onnx.data" },
        @{ Local = "decoder_model.onnx"; Key = "ie_decoder_model.onnx" },
        @{ Local = "decoder_with_past_model.onnx"; Key = "ie_decoder_with_past_model.onnx" },
        @{ Local = "decoder_shared.onnx.data"; Key = "ie_decoder_shared.onnx.data" },
        @{ Local = "model.SRC"; Key = "ie_model.SRC" },
        @{ Local = "model.TGT"; Key = "ie_model.TGT" },
        @{ Local = "dict.SRC.json"; Key = "ie_dict.SRC.json" },
        @{ Local = "dict.TGT.json"; Key = "ie_dict.TGT.json" }
    )

    foreach ($item in $indicEnFiles) {
        $lPath = "$IndicEnSource\\$($item.Local)"
        Provision-And-VerifyFile -LocalPath $lPath -RemoteDir "$targetPrimary/indic-en-models" -Device $deviceSerial -ManifestKey $item.Key
    }
}
'''

summary_target = 'Write-Host "`n==========================================================" -ForegroundColor Green\nWrite-Host "   ALL 19 MODEL FILES TRANSFERRED & VERIFIED PASS!        " -ForegroundColor Green'
summary_replacement = indic_en_block + '\n' + 'Write-Host "`n==========================================================" -ForegroundColor Green\nWrite-Host "   OFFLINE MODEL PROVISIONING & VERIFICATION COMPLETE!    " -ForegroundColor Green'

text = text.replace(summary_target, summary_replacement)

with open(r'C:\AnuvaadAI Anti\scripts\setup\provision_models.ps1', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text)

print('Updated provision_models.ps1 successfully')
