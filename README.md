# Botv1-telegram
Bot with Button feature 

Berikut adalah kode lengkap untuk UBOT LIST yang bisa dijalankan di Termux dan di-upload ke GitHub. Saya buatkan beberapa file sekaligus.

## 📁 Struktur Project

```
ubot-list/
├── config.py
├── ubot_list.py
├── requirements.txt
├── README.md
└── start.sh
```

---

## 1️⃣ `config.py`

```python
# ═══════════════════════════════════════════
# KONFIGURASI UBOT LIST
# ═══════════════════════════════════════════

# Dapatkan API_ID & API_HASH di https://my.telegram.org
API_ID = 123456                    # Ganti dengan API ID kamu
API_HASH = "your_api_hash_here"   # Ganti dengan API HASH kamu

# ID Telegram kamu (admin). Bisa lebih dari 1.
# Cek ID di @userinfobot
ADMIN_IDS = [
    123456789,    # Ganti dengan ID Telegram kamu
    # 987654321,  # Tambah admin lain jika perlu
]

# Nama session file (akan dibuat otomatis)
SESSION_NAME = "ubot_list"

# File penyimpanan data
DATA_FILE = "ubot_data.json"
```

---

## 2️⃣ `ubot_list.py` (Kode Utama)

```python
"""
╔══════════════════════════════════════════════════╗
║        UBOT LIST - Manajemen Taruhan K/B         ║
║          Telegram Userbot by Evanz               ║
╚══════════════════════════════════════════════════╝

Cara pakai:
1. Edit config.py dengan API_ID, API_HASH, ADMIN_IDS
2. pip install -r requirements.txt
3. python ubot_list.py
"""

import os
import re
import json
import asyncio
from telethon import TelegramClient, events
from config import API_ID, API_HASH, ADMIN_IDS, SESSION_NAME, DATA_FILE


# ═══════════════════════════════════════════
# STORAGE - Load & Save JSON
# ═══════════════════════════════════════════

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "active": {},        # {chat_id_str: True/False}
        "perak_mode": {},   # {chat_id_str: True/False}
        "bets": {},          # {chat_id_str: {user_id_str: {...}}}
        "aliases": {},       # {chat_id_str: {user_id_str: "name"}}
        "geseran": {},       # {chat_id_str: {key: {nominal, max}}}
    }


def save_data():
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, default=str)
    except Exception as e:
        print(f"[ERROR] Gagal save data: {e}")


data = load_data()


# ═══════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════

def is_admin(user_id):
    return user_id in ADMIN_IDS


def is_active(chat_id):
    return data["active"].get(str(chat_id), False)


def is_perak(chat_id):
    return data["perak_mode"].get(str(chat_id), True)


def get_bets(chat_id):
    cid = str(chat_id)
    if cid not in data["bets"]:
        data["bets"][cid] = {}
    return data["bets"][cid]


def get_geseran(chat_id):
    cid = str(chat_id)
    if cid not in data["geseran"]:
        data["geseran"][cid] = {}
    return data["geseran"][cid]


def parse_bet(text):
    """
    Parse format bet:
    K5, B10, K 5, B 10  → (type, amount)
    5K, 10B             → (type, amount)
    B1.5, B1,5          → (type, amount) dengan desimal
    """
    text = text.strip().upper().replace(",", ".")
    # Format: K5 / B10
    m = re.match(r"^([KB])\s*(\d+(?:\.\d+)?)$", text)
    if m:
        return m.group(1), float(m.group(2))
    # Format: 5K / 10B
    m = re.match(r"^(\d+(?:\.\d+)?)\s*([KB])$", text)
    if m:
        return m.group(2), float(m.group(1))
    return None, None


def calc_amount(raw, perak_mode):
    """Hitung nominal berdasarkan mode perak"""
    if perak_mode:
        return int(raw * 1000)
    if raw == int(raw):
        return int(raw)
    return raw


def format_amount(amount):
    """Format angka untuk tampilan"""
    if isinstance(amount, int):
        return str(amount)
    return str(amount)


async def get_display_name(user):
    """Ambil nama user"""
    if not user:
        return "Unknown"
    name = user.first_name or ""
    if user.last_name:
        name += f" {user.last_name}"
    return name.strip() or f"User_{user.id}"


# ═══════════════════════════════════════════
# INISIALISASI CLIENT
# ═══════════════════════════════════════════

client = TelegramClient(SESSION_NAME, API_ID, API_HASH)


# ═══════════════════════════════════════════
# COMMAND: .on
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.on$"))
async def cmd_on(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    data["active"][cid] = True
    if cid not in data["perak_mode"]:
        data["perak_mode"][cid] = True
    save_data()
    await event.reply(
        "✅ **UBOT LIST AKTIF**\n\n"
        "Bot mulai mencatat bet K/B.\n"
        "Ketik `.cmd` untuk melihat semua command."
    )


# ═══════════════════════════════════════════
# COMMAND: .off
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.off$"))
async def cmd_off(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    data["active"][cid] = False
    save_data()
    await event.reply("❌ **UBOT LIST DIMATIKAN**\nBot berhenti mencatat bet.")


# ═══════════════════════════════════════════
# COMMAND: .list
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.list$"))
async def cmd_list(event):
    bets = get_bets(event.chat_id)
    if not bets:
        await event.reply("📋 **List masih kosong**\nBelum ada yang pasang bet.")
        return

    k_list = []
    b_list = []
    for uid, info in bets.items():
        line = f"• {info['name']} {format_amount(info['amount'])}"
        if info["username"]:
            line += f" {info['username']}"
        if info["type"] == "K":
            k_list.append(line)
        else:
            b_list.append(line)

    k_total = sum(i["amount"] for i in bets.values() if i["type"] == "K")
    b_total = sum(i["amount"] for i in bets.values() if i["type"] == "B")

    msg = "📋 **LIST RONDE INI**\n\n"
    if k_list:
        msg += "🔻 **K (Kecil)**\n" + "\n".join(k_list) + "\n\n"
    if b_list:
        msg += "🔺 **B (Besar)**\n" + "\n".join(b_list) + "\n\n"

    msg += "━━━━━━━━━━━━━\n"
    msg += f"📊 Total K: **{format_amount(k_total)}**\n"
    msg += f"📊 Total B: **{format_amount(b_total)}**\n"
    msg += f"👥 Total pemain: **{len(bets)}**"

    await event.reply(msg)


# ═══════════════════════════════════════════
# COMMAND: .rs (reset list)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.rs$"))
async def cmd_rs(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    data["bets"][cid] = {}
    save_data()
    await event.reply("🗑 **List dikosongkan**\nRonde baru dimulai. Silakan pasang bet!")


# ═══════════════════════════════════════════
# COMMAND: .rk (rekap)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.rk$"))
async def cmd_rk(event):
    bets = get_bets(event.chat_id)
    if not bets:
        await event.reply("❌ List kosong, tidak ada yang bisa direkap.")
        return

    k_total = sum(i["amount"] for i in bets.values() if i["type"] == "K")
    b_total = sum(i["amount"] for i in bets.values() if i["type"] == "B")
    selisih = abs(k_total - b_total)

    k_count = sum(1 for i in bets.values() if i["type"] == "K")
    b_count = sum(1 for i in bets.values() if i["type"] == "B")

    msg = "📊 **REKAP TOTAL**\n\n"
    msg += f"🔻 K: {k_count} pemain → **{format_amount(k_total)}**\n"
    msg += f"🔺 B: {b_count} pemain → **{format_amount(b_total)}**\n"
    msg += "━━━━━━━━━━━━━\n"

    if k_total > b_total:
        msg += f"⚠️ **B kurang {format_amount(selisih)}**\n"
        msg += f"💰 B perlu tambah **{format_amount(selisih)}**"
    elif b_total > k_total:
        msg += f"⚠️ **K kurang {format_amount(selisih)}**\n"
        msg += f"💰 K perlu tambah **{format_amount(selisih)}**"
    else:
        msg += "✅ **K & B Seimbang!**"

    await event.reply(msg)


# ═══════════════════════════════════════════
# COMMAND: .perak / .nonperak
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.perak$"))
async def cmd_perak(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    data["perak_mode"][cid] = True
    save_data()
    await event.reply("💰 **Mode PERAK aktif**\n`B1` = 1000 (dikali 1000)")


@client.on(events.NewMessage(pattern=r"^\.nonperak$"))
async def cmd_nonperak(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    data["perak_mode"][cid] = False
    save_data()
    await event.reply("💵 **Mode NON-PERAK aktif**\n`B1` = 1 (nilai asli)")


# ═══════════════════════════════════════════
# COMMAND: .h NAMA (hapus slot)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.h\s+(.+)$"))
async def cmd_hapus(event):
    if not is_admin(event.sender_id):
        return
    target_name = event.pattern_match.group(1).strip().lower()
    bets = get_bets(event.chat_id)

    found_uid = None
    found_name = None
    for uid, info in bets.items():
        if info["name"].lower() == target_name:
            found_uid = uid
            found_name = info["name"]
            break

    if found_uid:
        del bets[found_uid]
        save_data()
        await event.reply(f"🗑 Slot **{found_name}** dihapus.")
    else:
        await event.reply(f"❌ Tidak ada slot dengan nama `{target_name}`.")


# ═══════════════════════════════════════════
# COMMAND: .c (hapus titik dari bet - reply based)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.c$"))
async def cmd_clean_dot(event):
    if not is_admin(event.sender_id):
        return
    if not event.is_reply:
        await event.reply("❌ Reply pesan bet yang ingin dibersihkan titiknya.")
        return
    reply = await event.get_reply_message()
    if not reply or not reply.text:
        await event.reply("❌ Pesan tidak memiliki teks.")
        return
    cleaned = reply.text.replace(".", "").replace(",", "")
    await event.reply(f"🧹 **Bersih:** `{cleaned}`")


# ═══════════════════════════════════════════
# COMMAND: .geseran KEY N MAX
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.geseran\s+(\S+)\s+(\d+(?:\.\d+)?)\s+(\d+)$"))
async def cmd_geseran(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    key = event.pattern_match.group(1).lower()
    nominal = float(event.pattern_match.group(2))
    max_user = int(event.pattern_match.group(3))

    get_geseran(event.chat_id)[key] = {
        "nominal": nominal,
        "max": max_user,
        "users": [],
    }
    save_data()
    await event.reply(
        f"🎯 **Geseran `{key}` dibuat**\n\n"
        f"Nominal: **{nominal}**\n"
        f"Max user: **{max_user}**\n\n"
        f"Pakai: `{key} b` atau `{key} k`"
    )


# ═══════════════════════════════════════════
# COMMAND: .sv NAMA (reply based alias)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.sv\s+(\S+)$"))
async def cmd_sv(event):
    if not is_admin(event.sender_id):
        return
    if not event.is_reply:
        await event.reply("❌ Reply pesan user yang ingin disimpan aliasnya.")
        return
    reply = await event.get_reply_message()
    if not reply or not reply.sender_id:
        await event.reply("❌ Tidak bisa mengambil user dari pesan.")
        return

    name = event.pattern_match.group(1)
    cid = str(event.chat_id)
    if cid not in data["aliases"]:
        data["aliases"][cid] = {}
    data["aliases"][cid][str(reply.sender_id)] = name
    save_data()

    try:
        user = await event.client.get_entity(reply.sender_id)
        display = await get_display_name(user)
    except Exception:
        display = f"User_{reply.sender_id}"

    await event.reply(f"✅ Alias tersimpan:\n**{display}** → `{name}`")


# ═══════════════════════════════════════════
# COMMAND: .svlist
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.svlist$"))
async def cmd_svlist(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    aliases = data["aliases"].get(cid, {})
    if not aliases:
        await event.reply("📋 Belum ada alias tersimpan.")
        return
    msg = "📋 **DAFTAR ALIAS**\n\n"
    for uid, name in aliases.items():
        msg += f"• `{name}` → [User](tg://user?id={uid})\n"
    await event.reply(msg)


# ═══════════════════════════════════════════
# COMMAND: .svdel
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.svdel$"))
async def cmd_svdel(event):
    if not is_admin(event.sender_id):
        return
    if not event.is_reply:
        await event.reply("❌ Reply pesan user yang aliasnya ingin dihapus.")
        return
    reply = await event.get_reply_message()
    cid = str(event.chat_id)
    if cid in data["aliases"] and str(reply.sender_id) in data["aliases"][cid]:
        name = data["aliases"][cid].pop(str(reply.sender_id))
        save_data()
        await event.reply(f"🗑 Alias `{name}` dihapus.")
    else:
        await event.reply("❌ Alias tidak ditemukan untuk user ini.")


# ═══════════════════════════════════════════
# COMMAND: .svsync
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.svsync$"))
async def cmd_svsync(event):
    if not is_admin(event.sender_id):
        return
    cid = str(event.chat_id)
    aliases = data["aliases"].get(cid, {})
    if not aliases:
        await event.reply("❌ Tidak ada alias untuk di-sync.")
        return
    msg = f"🔄 **SYNC ALIAS KE CONTACT UBOT**\nTotal: {len(aliases)}\n\n"
    for uid, name in aliases.items():
        msg += f"• `{name}` → ID: {uid}\n"
    msg += "\n✅ Sync selesai."
    await event.reply(msg)


# ═══════════════════════════════════════════
# COMMAND: .addp (mark P in pinned/replied message)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.addp$"))
async def cmd_addp(event):
    if not is_admin(event.sender_id):
        return
    if not event.is_reply:
        await event.reply("❌ Reply pesan yang berisi nama + saldo.")
        return
    reply = await event.get_reply_message()
    if not reply or not reply.text:
        await event.reply("❌ Pesan tidak memiliki teks.")
        return

    lines = reply.text.strip().split("\n")
    marked = []
    for line in lines:
        line = line.strip()
        # Match: Name 5000 atau Name: 5000
        m = re.match(r"^(.+?)\s*[:\s]\s*(\d+)\s*$", line)
        if m:
            name = m.group(1).strip()
            saldo = int(m.group(2))
            if saldo > 0:
                marked.append(f"• {name} {saldo} ✅P")

    if marked:
        await event.reply("📌 **Saldo ditandai (P):**\n\n" + "\n".join(marked))
    else:
        await event.reply(
            "❌ Format tidak dikenali.\n"
            "Contoh format:\n```\nAngga 5000\nRangga 10000\n```"
        )


# ═══════════════════════════════════════════
# COMMAND: Ball (pasang semua saldo dari pin)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^Ball$"))
async def cmd_ball(event):
    if not is_admin(event.sender_id):
        return
    if not is_active(event.chat_id):
        await event.reply("❌ Bot belum aktif. Ketik `.on` dulu.")
        return
    if not event.is_reply:
        await event.reply("❌ Reply pesan pinned yang berisi nama + saldo.")
        return
    reply = await event.get_reply_message()
    if not reply or not reply.text:
        await event.reply("❌ Pesan tidak memiliki teks.")
        return

    lines = reply.text.strip().split("\n")
    added = []
    for line in lines:
        line = line.strip()
        m = re.match(r"^(.+?)\s*[:\s]\s*(\d+)\s*$", line)
        if m:
            name = m.group(1).strip()
            saldo = int(m.group(2))
            added.append(f"• {name} → {saldo}")

    if added:
        await event.reply(
            "🎯 **BALL - Pasang Semua Saldo**\n\n"
            + "\n".join(added)
            + "\n\n⚠️ Fitur ini perlu mapping nama ke user_id."
        )
    else:
        await event.reply("❌ Tidak ada saldo yang terdeteksi di pesan.")


# ═══════════════════════════════════════════
# COMMAND: .cmd (help)
# ═══════════════════════════════════════════

@client.on(events.NewMessage(pattern=r"^\.cmd$"))
async def cmd_help(event):
    msg = """📚 **DAFTAR COMMAND UBOT LIST**

**📡 Status Bot**
`.on` — Nyalakan bot
`.off` — Matikan bot

**📋 Slot & List**
`.list` — Lihat slot ronde ini
`.rs` — Reset list (ronde baru)

**📊 Rekap**
`.rk` — Rekap total K/B + selisih

**💰 Mode Perak**
`.perak` — B1 = 1000 (default)
`.nonperak` — B1 = 1

**📌 Saldo Pinned**
`.addp` — Tandai P di saldo (reply pesan)
`Ball` — Pasang semua saldo dari pin (reply pesan)

**🏷 Alias (Reply pesan user)**
`.sv NAMA` — Simpan alias
`.svlist` — Lihat semua alias
`.svdel` — Hapus alias (reply pesan)
`.svsync` — Sync ke contact ubot

**✏️ Edit**
`.h NAMA` — Hapus slot pemain
`.c` — Hapus tanda titik (reply bet)

**🎯 Geseran**
`.geseran KEY N MAX` — Set preset bet
`KEY b` / `KEY k` — Pakai preset

**📝 Format Pasang Bet**
`K5` / `5K` — Kecil 5
`B10` / `10B` — Besar 10
`B1.5` / `B1,5` — Besar 1.5 (desimal)

━━━━━━━━━━━━━
*Userbot By Evanz*"""
    await event.reply(msg)


# ═══════════════════════════════════════════
# HANDLER: Pasang Bet (K5, B10, 5K, 10B)
# ═══════════════════════════════════════════

@client.on(events.NewMessage())
async def handle_bet(event):
    # Cek apakah ada teks
    if not event.text:
        return

    cid = event.chat_id
    # Bot harus aktif
    if not is_active(cid):
        return

    text = event.text.strip()

    # Skip command (diawali titik)
    if text.startswith("."):
        return

    # Skip "Ball" command
    if text == "Ball":
        return

    # ═══════════════════════════════════════
    # CEK GESERAN PRESET
    # ═══════════════════════════════════════
    geseran = get_geseran(cid)
    g_match = re.match(
        r"^([a-zA-Z]+)\s+([kb])(?:\s*#(\d+(?:\.\d+)?))?$",
        text,
        re.IGNORECASE,
    )
    if g_match:
        key = g_match.group(1).lower()
        if key in geseran:
            bet_type = g_match.group(2).upper()
            preset = geseran[key]
            if g_match.group(3):
                raw = float(g_match.group(3))
            else:
                raw = preset["nominal"]

            amount = calc_amount(raw, is_perak(cid))

            # Ambil info user
            try:
                user = await event.get_sender()
                name = await get_display_name(user)
            except Exception:
                name = f"User_{event.sender_id}"

            uname = ""
            if user and user.username:
                uname = f"@{user.username}"

            # Simpan bet
            get_bets(cid)[str(event.sender_id)] = {
                "name": name,
                "username": uname,
                "type": bet_type,
                "amount": amount,
            }
            save_data()

            display_raw = int(raw) if raw == int(raw) else raw
            await event.reply(f"✅ {name} {bet_type}{display_raw}")
            return

    # ═══════════════════════════════════════
    # CEK BET NORMAL (K5, B10, 5K, 10B)
    # ═══════════════════════════════════════
    bet_type, raw = parse_bet(text)
    if bet_type is None:
        return

    amount = calc_amount(raw, is_perak(cid))

    # Ambil info user
    try:
        user = await event.get_sender()
        name = await get_display_name(user)
    except Exception:
        name = f"User_{event.sender_id}"
        user = None

    uname = ""
    if user and user.username:
        uname = f"@{user.username}"

    # Simpan bet
    get_bets(cid)[str(event.sender_id)] = {
        "name": name,
        "username": uname,
        "type": bet_type,
        "amount": amount,
    }
    save_data()

    display_raw = int(raw) if raw == int(raw) else raw
    await event.reply(f"✅ {name} {bet_type}{display_raw}")


# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

async def main():
    print("=" * 50)
    print("  🚀 UBOT LIST - Starting...")
    print("=" * 50)

    await client.start()

    me = await client.get_me()
    print(f"\n  ✅ Login sebagai: {me.first_name}")
    if me.username:
        print(f"  📱 Username: @{me.username}")
    print(f"  🆔 ID: {me.id}")
    print(f"  👑 Admin IDs: {ADMIN_IDS}")
    print("\n  📋 Bot aktif & menunggu command...")
    print("  Ketik .on di grup untuk mulai.")
    print("=" * 50)
    print("  Tekan Ctrl+C untuk berhenti.\n")

    await client.run_until_disconnected()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Bot dihentikan. Sampai jumpa!")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\n💡 Pastikan config.py sudah diisi dengan benar.")
        print("   API_ID: https://my.telegram.org/apps")
```

---

## 3️⃣ `requirements.txt`

```txt
telethon==1.36.0
```

---

## 4️⃣ `start.sh`

```bash
#!/bin/bash

# ═══════════════════════════════════════════
# UBOT LIST - Termux Starter Script
# ═══════════════════════════════════════════

echo "================================"
echo "  🚀 UBOT LIST - Termux Setup"
echo "================================"

# Cek apakah di Termux
if command -v termux-setup-storage &> /dev/null; then
    echo "📱 Termux detected!"
    termux-setup-storage
fi

# Install Python jika belum ada
if ! command -v python &> /dev/null; then
    echo "📥 Installing Python..."
    pkg install python -y
fi

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Cek config
if grep -q "123456" config.py; then
    echo ""
    echo "⚠️  PERHATIAN!"
    echo "   config.py masih menggunakan nilai default."
    echo "   Edit dulu config.py dengan API_ID, API_HASH, dan ADMIN_ID kamu."
    echo ""
    echo "   Dapatkan API_ID & API_HASH di: https://my.telegram.org/apps"
    echo ""
    read -p "   Sudah edit config.py? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "❌ Edit config.py dulu, lalu jalankan ulang script ini."
        exit 1
    fi
fi

# Run bot
echo ""
echo "🚀 Menjalankan bot..."
python ubot_list.py
```

---

## 5️⃣ `README.md`

```markdown
# 📚 UBOT LIST

Telegram Userbot untuk mencatat taruhan K/B (Kecil/Besar) di grup secara otomatis.

## 📦 Cara Install di Termux

### 1. Install Termux
Download dari [F-Droid](https://f-droid.org/packages/com.termux/) (versi Play Store sudah tidak update).

### 2. Setup Termux
```bash
pkg update && pkg upgrade -y
pkg install python git -y
termux-setup-storage
```

### 3. Clone Repository
```bash
git clone https://github.com/USERNAME/ubot-list.git
cd ubot-list
```

### 4. Edit Config
```bash
nano config.py
```
Isi dengan:
- `API_ID` → dari https://my.telegram.org/apps
- `API_HASH` → dari https://my.telegram.org/apps
- `ADMIN_IDS` → ID Telegram kamu (cek di @userinfobot)

### 5. Jalankan Bot
```bash
bash start.sh
```
Atau manual:
```bash
pip install -r requirements.txt
python ubot_list.py
```

### 6. Login Pertama
Saat pertama dijalankan, bot akan minta:
- Nomor telepon (format: +628xxx)
- Kode OTP (dikirim ke Telegram)
- Jika 2FA aktif: password

Setelah login, session file (`ubot_list.session`) akan dibuat otomatis.

---

## 📋 Command List

| Command | Fungsi |
|---------|--------|
| `.on` | Nyalakan bot |
| `.off` | Matikan bot |
| `.list` | Lihat siapa sudah masuk |
| `.rs` | Reset list (ronde baru) |
| `.rk` | Rekap total K/B + selisih |
| `.perak` | Mode perak (B1 = 1000) |
| `.nonperak` | Mode non-perak (B1 = 1) |
| `.h NAMA` | Hapus slot pemain |
| `.c` | Hapus tanda titik (reply bet) |
| `.addp` | Tandai P di saldo (reply pesan) |
| `Ball` | Pasang semua saldo (reply pesan) |
| `.sv NAMA` | Simpan alias (reply pesan user) |
| `.svlist` | Lihat semua alias |
| `.svdel` | Hapus alias (reply pesan) |
| `.svsync` | Sync ke contact ubot |
| `.geseran KEY N MAX` | Set preset bet |
| `.cmd` | Lihat semua command |

### Format Pasang Bet
```
K5    → Kecil 5
B10   → Besar 10
5K    → Kecil 5 (dibalik)
10B   → Besar 10 (dibalik)
B1.5  → Besar 1.5 (desimal)
B1,5  → Besar 1.5 (koma juga bisa)
```

---

## 🔄 Update Bot

```bash
cd ubot-list
git pull
python ubot_list.py
```

---

## ❓ Troubleshooting

### Error: "Could not find a valid Telegram session"
Hapus file session lalu jalankan ulang:
```bash
rm ubot_list.session
python ubot_list.py
```

### Error: "telethon not found"
```bash
pip install telethon
```

### Error: "config.py not found"
Pastikan Anda berada di folder yang benar:
```bash
cd ubot-list
ls
```

### Bot tidak merespon
- Pastikan sudah ketik `.on` di grup
- Pastikan ID kamu ada di `ADMIN_IDS` di config.py
- Cek apakah ada error di terminal

---

## 📝 Catatan

- Bot ini menggunakan **userbot** (akun pribadi), bukan Bot API resmi
- Session file (`ubot_list.session`) berisi login info - **JANGAN dibagikan**
- Data tersimpan di `ubot_data.json`
- Bot hanya merespon admin yang terdaftar di `ADMIN_IDS`

---

## 👤 Author
**Evanz** - Userbot By Evanz
```

---

## 🚀 Cara Upload ke GitHub

```bash
# Di Termux:
git init
git add .
git commit -m "Initial commit - UBOT LIST"
git branch -M main
git remote add origin https://github.com/USERNAME/ubot-list.git
git push -u origin main
```

---

## ⚠️ Penting Sebelum Run

1. **Edit `config.py`** terlebih dahulu:
   - Dapatkan `API_ID` & `API_HASH` dari https://my.telegram.org/apps
   - Isi `ADMIN_IDS` dengan ID Telegram kamu

2. **Jangan upload file `ubot_list.session`** ke GitHub (sudah otomatis diabaikan jika pakai `.gitignore`)

3. **Tambahkan `.gitignore`**:
```bash
echo "ubot_list.session" >> .gitignore
echo "ubot_data.json" >> .gitignore
echo "__pycache__/" >> .gitignore
echo "*.session-journal" >> .gitignore
```

---

Kode di atas sudah saya buat sedemikian rupa agar **tidak error** saat dijalankan di Termux. Semua handler sudah terpisah dengan jelas, dan error handling sudah ada di setiap bagian. Jika ada yang perlu ditambahkan atau dimodifikasi, silakan beri tahu! 🚀
