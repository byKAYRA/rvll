#!/usr/bin/env python3
"""
Revival Mobile manifest.json Generator
Scans client/ directory and madeira.cfg, computes SHA-256 hashes and file sizes,
and outputs a ready-to-use manifest.json for RevivalSyncEngine.
"""
import os
import json
import hashlib
from datetime import datetime, timezone

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_RAW_URL = "https://raw.githubusercontent.com/byKAYRA/rvll/main"

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest().lower()

def main():
    manifest_items = []

    # 1. madeira.cfg
    cfg_path = os.path.join(REPO_ROOT, "madeira.cfg")
    if os.path.isfile(cfg_path):
        manifest_items.append({
            "target_path": "madeira.cfg",
            "url": f"{BASE_RAW_URL}/madeira.cfg",
            "sha256": sha256_file(cfg_path),
            "size": os.path.getsize(cfg_path)
        })

    # 2. client/ directory
    client_dir = os.path.join(REPO_ROOT, "client")
    if os.path.isdir(client_dir):
        for root, dirs, files in os.walk(client_dir):
            for file in sorted(files):
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, client_dir).replace("\\", "/")
                target_path = f"Revival/{rel_path}"
                raw_url = f"{BASE_RAW_URL}/client/{rel_path}"
                
                manifest_items.append({
                    "target_path": target_path,
                    "url": raw_url,
                    "sha256": sha256_file(abs_path),
                    "size": os.path.getsize(abs_path)
                })

    manifest = {
        "version": "1.0.0",
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "files": manifest_items
    }

    manifest_output_path = os.path.join(REPO_ROOT, "manifest.json")
    with open(manifest_output_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"Generated manifest.json with {len(manifest_items)} items at {manifest_output_path}")

if __name__ == "__main__":
    main()
