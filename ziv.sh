#!/bin/bash

# ==========================================
# Konfigurasi File & Variabel
# ==========================================
CONF="/etc/zivpn/config.json"
DOM_FILE="/etc/zivpn/domain"
MYIP=$(curl -s ifconfig.me)
[[ -f $DOM_FILE ]] && DOM=$(cat $DOM_FILE) || DOM=$MYIP

# Warna
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; B='\033[0;34m'; P='\033[0;35m'; C='\033[0;36m'; NC='\033[0m'

# ==========================================
# FUNGSI FIX KONEKSI (SINKRONISASI TOTAL)
# ==========================================
sync_ziv() {
    # 1. Ambil daftar user premium (UID >= 1000)
    # Kita ambil username-nya saja sebagai password (standard ZiVPN)
    user_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    
    # 2. Tambahkan password default 'zi' agar selalu ada isi
    if [[ -z $user_list ]]; then
        final_config="\"zi\""
    else
        final_config="\"zi\", $user_list"
    fi

    # 3. REWRITE CONFIG (Menulis ulang file agar tidak error format JSON)
    # Ini adalah bagian paling krusial agar ZiVPN mau konek
    cat > $CONF << END
{
  "password": "zi",
  "config": [$final_config]
}
END

    # 4. Restart Service agar perubahan diterapkan
    systemctl daemon-reload
    systemctl restart zivpn.service
}

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
    echo -e "  ${C}IP      :${NC} $MYIP"
    echo -e "  ${C}DOMAIN  :${NC} $DOM"
    echo -e "  ${C}ZiVPN   :${NC} $(systemctl is-active zivpn.service | sed 's/active/Running/g' || echo "Stopped")"
    echo -e "${Y}└────────────────────────────────────────────────────────┘${NC}"
}

# --- Fitur Akun ---

create_acc() {
    header
    echo -e "          ${G}[ 01. CREATE PREMIUM ]${NC}"
    read -p "  Username : " user
    [[ -z $user ]] && return
    if id "$user" &>/dev/null; then
        echo -e "${R}  User sudah ada!${NC}"; sleep 2; return
    fi
    read -p "  Password : " pass
    read -p "  Aktif (Hari): " days
    
    exp=$(date -d "$days days" +"%Y-%m-%d")
    # Buat user sistem tanpa shell login
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    # Jalankan Fix Koneksi
    sync_ziv
    
    header
    echo -e "${G}  AKUN BERHASIL & KONEKSI FIX!${NC}"
    echo -e "  User     : $user"
    echo -e "  Pass     : $pass"
    echo -e "  Expired  : $(date -d "$days days" +"%d %b %Y")"
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    read -p "  Tekan Enter..."
}

delete_acc() {
    header
    echo -e "          ${R}[ 03. DELETE ACCOUNT ]${NC}"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print "  - " $1}' /etc/passwd
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    read -p "  User yang dihapus: " user
    if id "$user" &>/dev/null; then
        userdel -f "$user"
        sync_ziv
        echo -e "${G}  $user Berhasil Dihapus!${NC}"
    fi
    sleep 2
}

list_acc() {
    header
    echo -e "          ${Y}[ LIST AKUN AKTIF ]${NC}"
    printf "  ${C}%-15s %-15s %-10s${NC}\n" "USER" "EXPIRED" "STATUS"
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    while IFS=: read -r u _ _ _ _ _ _ e _; do
        if [[ $(id -u $u) -ge 1000 && $u != "nobody" ]]; then
            exp_d=$(date -d "1970-01-01 $e days" +"%d-%m-%Y" 2>/dev/null || echo "Permanent")
            printf "  %-15s %-15s ${G}%-10s${NC}\n" "$u" "$exp_d" "Aktif"
        fi
    done < /etc/shadow
    read -p "  Enter..."
}

# --- Menu Utama ---
while true; do
    header
    echo -e "  ${Y}1)${NC} Buat Akun Premium   ${Y}5)${NC} Daftar Akun"
    echo -e "  ${Y}2)${NC} Buat Akun Trial     ${Y}6)${NC} Hapus Expired"
    echo -e "  ${Y}3)${NC} Hapus Akun          ${Y}7)${NC} Restart ZiVPN"
    echo -e "  ${Y}4)${NC} Ganti Domain        ${Y}8)${NC} Speedtest"
    echo -e "  ${R}0)${NC} Keluar"
    echo -e "${Y}┌────────────────────────────────────────────────────────┐${NC}"
    read -p "  Pilihan [0-8]: " opt
    case $opt in
        1) create_acc ;;
        2) u="tr-$(($RANDOM%900+100))"; useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u; echo "$u:1" | chpasswd; sync_ziv; echo "Trial $u Aktif 1 Jam"; sleep 2 ;;
        3) delete_acc ;;
        4) header; read -p "  Domain: " d; [[ -n $d ]] && echo "$d" > $DOM_FILE && DOM=$d; sync_ziv ;;
        5) list_acc ;;
        6) now=$(($(date +%s)/86400)); while IFS=: read -r u _ _ _ _ _ _ e _; do [[ -n $e && $now -ge $e && $(id -u $u) -ge 1000 ]] && userdel -f $u; done < /etc/shadow; sync_ziv; echo "Cleaned!"; sleep 1 ;;
        7) systemctl restart zivpn.service; echo "Restarted."; sleep 1 ;;
        8) header; curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
        0) exit ;;
    esac
done
