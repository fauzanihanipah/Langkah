#!/bin/bash

# ==========================================
# Konfigurasi Path & Variabel
# ==========================================
CONF="/etc/zivpn/config.json"
DOM_FILE="/etc/zivpn/domain"
MYIP=$(curl -s ifconfig.me)
[[ -f $DOM_FILE ]] && DOM=$(cat $DOM_FILE) || DOM=$MYIP

# Warna (Cyan, Green, Yellow, Purple, Red)
C='\033[0;36m'; G='\033[0;32m'; Y='\033[0;33m'; P='\033[0;35m'; R='\033[0;31m'; NC='\033[0m'

# ==========================================
# FUNGSI INTI: Sinkronisasi ZiVPN (Fix Connection)
# ==========================================
sync_ziv() {
    # Ambil user dengan UID 1000+ (User Premium)
    users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    [[ -z $users ]] && final="\"zi\"" || final="\"zi\", $users"

    # Rewrite Config agar format JSON selalu valid
    cat > $CONF << END
{
  "password": "zi",
  "config": [$final]
}
END
    systemctl restart zivpn.service &>/dev/null
}

# ==========================================
# Header Dashboard (Gaya OGHZIV)
# ==========================================
header() {
    clear
    echo -e "${P}"
    echo "  _   _  ____   ____     ___   ____ _   _ _____ _____     __"
    echo " | | | ||  _ \ |  _ \   / _ \ / ___| | | |__  /|_   _\ \   / /"
    echo " | | | || | | || |_) | | | | | |  _| |_| | / /   | |  \ \ / / "
    echo " | |_| || |_| ||  __/  | |_| | |_| |  _  |/ /_  _| |_  \ V /  "
    echo "  \___/ |____/ |_|      \___/ \____|_| |_/____||_____|  \_/   "
    echo -e "         ${Y}U D P   O G H Z I V   P R E M I U M${NC}"
    echo -e "${Y}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${C}OS      :${NC} $(lsb_release -ds 2>/dev/null || echo "Ubuntu Server")"
    echo -e "  ${C}IP/DOM  :${NC} $DOM ($MYIP)"
    echo -e "  ${C}RAM     :${NC} $(free -m | awk 'NR==2{printf "%sMB/%sMB (%.0f%%)", $3,$2,$3*100/$2 }')"
    echo -e "  ${C}ZiVPN   :${NC} $(systemctl is-active zivpn.service | sed 's/active/Running/g')"
    echo -e "${Y}└────────────────────────────────────────────────────────┘${NC}"
}

# ==========================================
# Menu Utama
# ==========================================
while true; do
    header
    echo -e "  ${Y}1)${NC} Buat Akun Premium   ${Y}5)${NC} Daftar Akun Aktif"
    echo -e "  ${Y}2)${NC} Buat Akun Trial     ${Y}6)${NC} Hapus Akun Expired"
    echo -e "  ${Y}3)${NC} Hapus Akun Manual   ${Y}7)${NC} Restart ZiVPN"
    echo -e "  ${Y}4)${NC} Ganti Domain        ${Y}8)${NC} Speedtest Server"
    echo -e "  ${R}0) Keluar Manager${NC}"
    echo -e "${Y}┌────────────────────────────────────────────────────────┐${NC}"
    read -p "  Pilih Menu [0-8]: " opt
    case $opt in
        1) # Create Premium
           header; read -p "  User: " u; read -p "  Pass: " p; read -p "  Hari: " d
           exp=$(date -d "$d days" +"%Y-%m-%d")
           useradd -e $exp -s /bin/false $u && echo "$u:$p" | chpasswd && sync_ziv
           header; echo -e "${G}  AKUN BERHASIL DIBUAT!${NC}"
           echo -e "  Host: $DOM | User: $u | Pass: $p | Exp: $exp"
           read -p "  Enter..." ;;
        2) # Trial 1 Jam
           header; u="tr-$(($RANDOM%900+100))"; useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u
           echo "$u:1" | chpasswd && sync_ziv
           echo "userdel -f $u; systemctl restart zivpn" | at now + 1 hour &>/dev/null
           echo -e "${G}  Trial $u (Pass: 1) Aktif 1 Jam!${NC}"; sleep 2 ;;
        3) # Delete Manual
           header; read -p "  Masukkan User yang akan dihapus: " u
           userdel -f $u && sync_ziv && echo -e "${G}User $u Dihapus!${NC}"; sleep 1 ;;
        4) # Domain
           header; read -p "  Input Domain Baru: " d; echo "$d" > $DOM_FILE; DOM=$d; sleep 1 ;;
        5) # List
           header; printf "  ${C}%-15s %-15s${NC}\n" "USER" "EXP DATE"
           while IFS=: read -r u _ _ _ _ _ _ e _; do
             [[ $(id -u $u) -ge 1000 && $u != "nobody" ]] && echo -e "  $u \t $(date -d "1970-01-01 $e days" +"%d-%m-%Y")"
           done < /etc/shadow; read -p "  Enter..." ;;
        6) # Auto XP
           now=$(($(date +%s)/86400))
           while IFS=: read -r u _ _ _ _ _ _ e _; do
             [[ -n $e && $now -ge $e && $(id -u $u) -ge 1000 ]] && userdel -f $u
           done < /etc/shadow && sync_ziv && echo "Expired Cleaned!"; sleep 1 ;;
        7) systemctl restart zivpn.service; echo "Restarted!"; sleep 1 ;;
        8) header; curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
        0) exit ;;
    esac
done
