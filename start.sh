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
