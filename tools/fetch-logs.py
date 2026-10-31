#!/usr/bin/env python3
"""
tools/fetch-logs.py
Revival Mobile (iOS) uzaktan teşhis loglarını filebin.net üzerinden çeker.
Kullanım:
    python tools/fetch-logs.py [--bin BIN_ID] [--out OUT_DIR]
"""

import sys
import os
import argparse
import urllib.request
import json

DEFAULT_BIN = "revival-logs-kayra"
BASE_URL = "https://filebin.net"

def main():
    if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        except Exception:
            pass

    parser = argparse.ArgumentParser(description="Revival Mobile Teşhis Logu Çekici")
    parser.add_argument("--bin", default=DEFAULT_BIN, help="Filebin ID (varsayılan: revival-logs-kayra)")
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "logs"), help="Hedef indirme dizini")
    parser.add_argument("--tail", type=int, default=35, help="Terminalde gösterilecek son satır sayısı")
    args = parser.parse_args()

    bin_url = f"{BASE_URL}/{args.bin}"
    print(f"[*] Filebin taranıyor: {bin_url}")

    req = urllib.request.Request(bin_url, headers={"Accept": "application/json", "User-Agent": "RevivalLogFetcher/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"[!] Hata: Filebin'e ulaşılamadı ({e})")
        print(f"[!] Henüz hiçbir log yüklenmemiş olabilir veya internet bağlantısı yok.")
        sys.exit(1)

    files = data.get("files", [])
    if not files:
        print(f"[-] Bin ({args.bin}) şu an boş. Cihazdan henüz log gönderilmemiş.")
        sys.exit(0)

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)
    print(f"[+] {len(files)} dosya bulundu. '{out_dir}' dizinine indiriliyor...\n")

    downloaded = {}
    for f in files:
        filename = f.get("filename")
        size = f.get("bytes", 0)
        updated = f.get("updated_at", "")
        file_url = f"{bin_url}/{filename}"
        dest_path = os.path.join(out_dir, filename)

        try:
            f_req = urllib.request.Request(file_url, headers={"User-Agent": "RevivalLogFetcher/1.0"})
            with urllib.request.urlopen(f_req, timeout=15) as f_resp:
                content = f_resp.read()
                with open(dest_path, "wb") as out_f:
                    out_f.write(content)
            downloaded[filename] = dest_path
            print(f"  [OK]    {filename:<25} ({size} bayt, güncellendi: {updated}) -> {dest_path}")
        except Exception as e:
            print(f"  [ERROR] {filename}: İndirilemedi ({e})")

    print("\n" + "="*60)
    print("  ÖZET RAPOR VE LOG İÇERİKLERİ")
    print("="*60)

    # 1. 00_system_info.txt
    if "00_system_info.txt" in downloaded:
        print("\n--- [00_system_info.txt] ---")
        try:
            with open(downloaded["00_system_info.txt"], "r", encoding="utf-8", errors="replace") as f:
                print(f.read().strip())
        except Exception as e:
            print(f"Okunamadı: {e}")

    # 2. launcher.log tail
    if "launcher.log" in downloaded:
        print(f"\n--- [launcher.log] (Son {args.tail} satır) ---")
        try:
            with open(downloaded["launcher.log"], "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
                for line in lines[-args.tail:]:
                    print(line, end="")
        except Exception as e:
            print(f"Okunamadı: {e}")

    # 3. ncrypt-shim.log tail
    if "ncrypt-shim.log" in downloaded:
        print(f"\n--- [ncrypt-shim.log] (Son {args.tail} satır) ---")
        try:
            with open(downloaded["ncrypt-shim.log"], "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
                for line in lines[-args.tail:]:
                    print(line, end="")
        except Exception as e:
            print(f"Okunamadı: {e}")

    # 4. madeira-log.txt tail
    if "madeira-log.txt" in downloaded:
        print(f"\n--- [madeira-log.txt] (Son {args.tail} satır) ---")
        try:
            with open(downloaded["madeira-log.txt"], "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
                for line in lines[-args.tail:]:
                    print(line, end="")
        except Exception as e:
            print(f"Okunamadı: {e}")

    print("\n" + "="*60)
    print(f"[OK] İndirme tamamlandı: {len(downloaded)}/{len(files)} dosya.")

if __name__ == "__main__":
    main()
