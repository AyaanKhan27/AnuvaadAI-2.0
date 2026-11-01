import zipfile
import hashlib
import os
import json

def get_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest().upper()

def inspect_apk(path):
    size = os.path.getsize(path)
    sha = get_sha256(path)
    
    with zipfile.ZipFile(path, "r") as z:
        entries = z.infolist()
        total_uncompressed = sum(e.file_size for e in entries)
        
        # Categorize
        categories = {
            "dex": 0,
            "native_libs": 0,
            "assets": 0,
            "res": 0,
            "other": 0
        }
        
        so_files = []
        asset_files = []
        model_files = []
        
        for e in entries:
            name = e.filename
            fsize = e.file_size
            if name.endswith(".dex"):
                categories["dex"] += fsize
            elif name.startswith("lib/"):
                categories["native_libs"] += fsize
                so_files.append((name, fsize))
            elif name.startswith("assets/"):
                categories["assets"] += fsize
                asset_files.append((name, fsize))
                if any(ext in name.lower() for ext in [".onnx", ".bin", ".tflite", ".pt", ".weights", ".safetensors"]):
                    model_files.append((name, fsize))
            elif name.startswith("res/"):
                categories["res"] += fsize
            else:
                categories["other"] += fsize
                
    return {
        "path": path,
        "size_bytes": size,
        "sha256": sha,
        "total_entries": len(entries),
        "total_uncompressed_bytes": total_uncompressed,
        "categories_bytes": categories,
        "so_files_count": len(so_files),
        "so_files": sorted(so_files, key=lambda x: x[1], reverse=True)[:15],
        "asset_files_count": len(asset_files),
        "model_files_in_apk": model_files
    }

rel_apk = r"C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk"
test_apk = r"C:\AnuvaadAI Anti\phase2_3_testing\AnuvaadAI-2.0-Phase2.3-TEST.apk"

print("Inspecting Release APK...")
rel_data = inspect_apk(rel_apk)

print("Inspecting Test APK...")
test_data = inspect_apk(test_apk)

output = {
    "release_apk": rel_data,
    "test_apk": test_data
}

out_path = r"C:\AnuvaadAI Anti\phase2_3_testing\apk_comparison_report.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(output, f, indent=2)

print(f"Report written to {out_path}")
print(f"Release APK SHA256: {rel_data['sha256']}")
print(f"Release APK Size:   {rel_data['size_bytes']} bytes")
print(f"Test APK SHA256:    {test_data['sha256']}")
print(f"Test APK Size:      {test_data['size_bytes']} bytes")
print(f"Model files in Release APK: {len(rel_data['model_files_in_apk'])}")
print(f"Model files in Test APK:    {len(test_data['model_files_in_apk'])}")
