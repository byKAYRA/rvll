#!/usr/bin/env python3
"""
tools/fetch-discord-logs.py
Revival Mobile (iOS) loglarını Discord kanalından çeker ve yerel logs/ dizinine kaydeder.
Kullanım:
    python tools/fetch-discord-logs.py [--limit 10] [--tail 35]
"""

import sys
import os
import argparse
import urllib.request
import json

# Terminal UTF-8 yapılandırması
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "discord_config.json")

BOT_TOKEN = os.getenv("DISCORD_BOT_TOKEN")
CHANNEL_ID = os.getenv("DISCORD_CHANNEL_ID", "1566118241640906994")

if os.path.exists(CONFIG_FILE):
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            BOT_TOKEN = cfg.get("bot_token", BOT_TOKEN)
            CHANNEL_ID = cfg.get("channel_id", CHANNEL_ID)
    except Exception:
        pass

if not BOT_TOKEN:
    print("[ERROR] Discord Bot Token bulunamadı. Lütfen tools/discord_config.json dosyasına ekleyin.")
    sys.exit(1)

API_URL = f"https://discord.com/api/v10/channels/{CHANNEL_ID}/messages"

def main():
    parser = argparse.ArgumentParser(description="Revival Mobile Discord Log Çekici")
    parser.add_argument("--limit", type=int, default=10, help="Taranacak son mesaj sayısı")
    parser.add_argument("--tail", type=int, default=35, help="Terminalde gösterilecek son satır sayısı")
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "logs"), help="Hedef indirme dizini")
    args = parser.parse_args()

    print(f"[*] Discord kanalı ({CHANNEL_ID}) taranıyor...")

    req = urllib.request.Request(f"{API_URL}?limit={args.limit}", headers={
        "Authorization": f"Bot {BOT_TOKEN}",
        "User-Agent": "RevivalDiscordLogFetcher/1.0"
    })

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            messages = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"[ERROR] Discord API hatası: {e}")
        sys.exit(1)

    target_msg = None
    for msg in messages:
        if msg.get("attachments"):
            target_msg = msg
            break

    if not target_msg:
        print("[-] Kanalda henüz dosya eki içeren bir log mesajı bulunamadı.")
        if messages:
            print(f"[*] Son mesaj: {messages[0].get('author', {}).get('username')}: {messages[0].get('content', '')}")
        sys.exit(0)

    attachments = target_msg.get("attachments", [])
    author = target_msg.get("author", {}).get("username", "Bilinmeyen")
    timestamp = target_msg.get("timestamp", "")
    print(f"[+] Log paketi bulundu! Gönderen: {author} (Zaman: {timestamp})")
    print(f"[+] Toplam {len(attachments)} dosya eki indiriliyor...\n")

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)

    downloaded = {}
    for att in attachments:
        filename = att.get("filename")
        size = att.get("size", 0)
        url = att.get("url")
        dest_path = os.path.join(out_dir, filename)

        try:
            f_req = urllib.request.Request(url, headers={"User-Agent": "RevivalDiscordLogFetcher/1.0"})
            with urllib.request.urlopen(f_req, timeout=15) as f_resp:
                content = f_resp.read()
                with open(dest_path, "wb") as out_f:
                    out_f.write(content)
            downloaded[filename] = dest_path
            print(f"  [OK]    {filename:<25} ({size} bayt) -> {dest_path}")
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
    print(f"[OK] İndirme tamamlandı: {len(downloaded)}/{len(attachments)} dosya '{out_dir}' dizinine kaydedildi.")

if __name__ == "__main__":
    main()
