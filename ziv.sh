#!/bin/bash

# ==========================================
# Color Definitions
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variabel Dasar
MYIP=$(curl -s ifconfig.me)
CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
[[ -f $DOMAIN_FILE ]] && DOM=$(cat $DOMAIN_FILE) || DOM=$MYIP

# Fungsi Sinkronisasi ZiVPN (Fix Koneksi)
sync_zivpn() {
    # Mengambil semua user sistem dengan UID >= 1000
    passwords=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    
    # Jika kosong, beri nilai default agar JSON tidak rusak
    if [[ -z $passwords ]]; then
        final_pass="\"zi\""
    else
        final_pass="\"zi\", $passwords"
    fi

    # Menulis ulang file config.json secara total untuk menjamin koneksi
    cat > $CONFIG_FILE << END
{
  "password": "zi",
  "config": [$final_pass]
}
END
    systemctl daemon-reload
    systemctl restart zivpn.service
}

# Tampilan Header Sesuai Gambar
header() {
    clear
    echo -e "${PURPLE}  _   _  ____   ____     ___   ____ _   _ _____ _____     __"
    echo -e " | | | ||  _ \ |  _ \   / _ \ / ___| | | |__  /|_   _\ \   / /"
    echo -e " | | | || | | || |_) | | | | | |  _| |_| | / /   | |  \ \ / / "
    echo -e " | |_| || |_| ||  __/  | |_| | |_| |  _  |/ /_  _| |_  \ V /  "
    echo -e "  \___/ |____/ |_|      \___/ \____|_| |_/____||_____|  \_/   ${NC}"
    echo -e "         ${YELLOW}U D P   O G H Z I V   P R E M I U M${NC}"
    echo -e "${YELLOW}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}OS      :${NC} $(lsb_release -ds 2>/dev/null || echo "Ubuntu 20.04.6 LTS")"
    echo -e "  ${CYAN}IP      :${NC} $MYIP"
    echo -e "  ${CYAN}DOMAIN  :${NC} $DOM"
    echo -e "  ${CYAN}ZiVPN   :${NC} $(systemctl is-active zivpn.service | sed 's/active/Running/g' || echo "activating")"
    echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
}

# Fungsi Buat Akun Premium
create_user() {
    header
    echo -e "          ${GREEN}[ BUAT AKUN PREMIUM ]${NC}"
    read -p "  Username : " user
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: User sudah ada!${NC}"; sleep 2; return
    fi
    read -p "  Password : " pass
    read -p "  Masa Aktif (Hari): " days

    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    sync_zivpn # Jalankan sinkronisasi agar langsung konek
    
    header
    echo -e "${GREEN}  AKUN BERHASIL & KONEKSI FIX!${NC}"
    echo -e "  Host/IP  : ${YELLOW}$DOM${NC}"
    echo -e "  IP VPS   : ${YELLOW}$MYIP${NC}"
    echo -e "  Username : ${YELLOW}$user${NC}"
    echo -e "  Password : ${YELLOW}$pass${NC}"
    echo -e "  Expired  : ${RED}$(date -d "$days days" +"%d %b %Y")${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────────────${NC}"
    read -p "Tekan Enter..."
}

# Fungsi Daftar Akun
list_users() {
    header
    echo -e "          ${YELLOW}[ DAFTAR AKUN AKTIF ]${NC}"
    printf "  ${CYAN}%-15s | %-15s | %-10s${NC}\n" "USERNAME" "EXP DATE" "STATUS"
    echo -e "${YELLOW}──────────────────────────────────────────────────────────${NC}"
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            expire=$(date -d "1970-01-01 $exp days" +"%d-%m-%Y" 2>/dev/null || echo "Permanent")
            echo -e "  $user \t $expire \t ${GREEN}Aktif${NC}"
        fi
    done < /etc/shadow
    read -p "Enter..."
}

# Menu Utama Berdasarkan Gambar
while true; do
    header
    echo -e "  ${YELLOW}1)${NC} Buat Akun Premium   ${YELLOW}5)${NC} Daftar Akun"
    echo -e "  ${YELLOW}2)${NC} Buat Akun Trial     ${YELLOW}6)${NC} Hapus Expired"
    echo -e "  ${YELLOW}3)${NC} Hapus Akun          ${YELLOW}7)${NC} Restart ZiVPN"
    echo -e "  ${YELLOW}4)${NC} Ganti Domain        ${Y}8)${NC} Speedtest"
    echo -e "  ${RED}0)${NC} Keluar"
    echo -e "${YELLOW}┌────────────────────────────────────────────────────────┐${NC}"
    read -p "  Pilihan [0-8]: " opt
    case $opt in
        1) create_user ;;
        2) # Trial 1 Jam
           header; u="trial$((RANDOM % 900 + 100))"; useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u; echo "$u:trial" | chpasswd; sync_zivpn
           echo "/usr/sbin/userdel -f $u; systemctl restart zivpn" | at now + 60 minutes &>/dev/null
           header
           echo -e "${GREEN}  AKUN TRIAL BERHASIL!${NC}"
           echo -e "  Host/IP  : $DOM"
           echo -e "  Username : $u"
           echo -e "  Password : trial"
           echo -e "  Aktif    : 1 Jam"
           read -p "Enter..." ;;
        3) header; read -p "  User dihapus: " user; userdel -f "$user"; sync_zivpn; echo "Deleted!"; sleep 1 ;;
        4) header; read -p "  Masukkan Domain: " d; echo "$d" > $DOMAIN_FILE; DOM=$d; sleep 1 ;;
        5) list_users ;;
        6) sync_zivpn; echo "Cleaned!"; sleep 2 ;;
        7) systemctl restart zivpn.service; echo "Restarted!"; sleep 1 ;;
        8) header; echo "Running Speedtest..."; curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
        0) exit ;;
        *) echo "Salah Pilihan"; sleep 1 ;;
    esac
done
