#!/bin/bash

# ==========================================
# Konfigurasi File & Variabel
# ==========================================
CONF="/etc/zivpn/config.json"
DOM_FILE="/etc/zivpn/domain"
MYIP=$(curl -s ifconfig.me)
[[ -f $DOM_FILE ]] && DOM=$(cat $DOM_FILE) || DOM=$MYIP

# Warna
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; 
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# ==========================================
# Fungsi Sinkronisasi (PENTING UNTUK KONEKSI)
# ==========================================
sync_zivpn() {
    # Ambil semua user premium (UID >= 1000)
    users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    
    # Format JSON agar valid
    if [[ -z $users ]]; then
        final_config="\"zi\""
    else
        final_config="\"zi\", $users"
    fi

    # Rewrite config.json total agar tidak ada error karakter
    cat > $CONF << END
{
  "password": "zi",
  "config": [$final_config]
}
END
    systemctl restart zivpn.service &>/dev/null
}

# ==========================================
# Tampilan Dashboard (Sesuai Gambar)
# ==========================================
header() {
    clear
    echo -e "${PURPLE}  _   _  ____   ____     ___   ____ _   _ _____ _____     __${NC}"
    echo -e "${PURPLE} | | | ||  _ \ |  _ \   / _ \ / ___| | | |__  /|_   _\ \   / /${NC}"
    echo -e "${PURPLE} | | | || | | || |_) | | | | | |  _| |_| | / /   | |  \ \ / / ${NC}"
    echo -e "${PURPLE} | |_| || |_| ||  __/  | |_| | |_| |  _  |/ /_  _| |_  \ V /  ${NC}"
    echo -e "${PURPLE}  \___/ |____/ |_|      \___/ \____|_| |_/____||_____|  \_/   ${NC}"
    echo -e "         ${YELLOW}U D P   O G H Z I V   P R E M I U M${NC}"
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}OS      :${NC} $(lsb_release -ds 2>/dev/null || echo "Ubuntu 20.04 LTS")"
    echo -e "  ${CYAN}IP      :${NC} $MYIP"
    echo -e "  ${CYAN}DOMAIN  :${NC} $DOM"
    echo -e "  ${CYAN}ZiVPN   :${NC} $(systemctl is-active zivpn.service | sed 's/active/activating/g' || echo "stopped")"
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────┘${NC}"
}

# ==========================================
# Fitur Akun
# ==========================================

create_user() {
    header
    echo -e "          ${GREEN}[ 01. BUAT AKUN PREMIUM ]${NC}"
    read -p "  Username : " user
    [[ -z $user ]] && return
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: User sudah ada!${NC}"; sleep 2; return
    fi
    read -p "  Password : " pass
    read -p "  Masa Aktif (Hari): " days
    
    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    sync_zivpn
    
    header
    echo -e "${GREEN}  AKUN BERHASIL DIAKTIFKAN!${NC}"
    echo -e "  Domain   : $DOM"
    echo -e "  Username : $user"
    echo -e "  Password : $pass"
    echo -e "  Expired  : $(date -d "$days days" +"%d %b %Y")"
    echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
    read -p "  Tekan Enter..."
}

delete_user() {
    header
    echo -e "          ${RED}[ 03. HAPUS AKUN ]${NC}"
    echo -e "  Daftar Akun:"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print "  - " $1}' /etc/passwd
    echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
    read -p "  Masukkan Username: " user
    if id "$user" &>/dev/null; then
        userdel -f "$user"
        sync_zivpn
        echo -e "${GREEN}  User $user berhasil dihapus!${NC}"
    else
        echo -e "${RED}  User tidak ditemukan!${NC}"
    fi
    sleep 2
}

list_users() {
    header
    echo -e "          ${YELLOW}[ DAFTAR AKUN AKTIF ]${NC}"
    printf "  ${CYAN}%-15s %-15s %-10s${NC}\n" "USERNAME" "EXPIRED" "STATUS"
    echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
    while IFS=: read -r u _ _ _ _ _ _ e _; do
        if [[ $(id -u $u) -ge 1000 && $u != "nobody" ]]; then
            exp_d=$(date -d "1970-01-01 $e days" +"%d-%m-%Y" 2>/dev/null || echo "Permanent")
            printf "  %-15s %-15s ${GREEN}%-10s${NC}\n" "$u" "$exp_d" "Aktif"
        fi
    done < /etc/shadow
    echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
    read -p "  Enter..."
}

# ==========================================
# Main Loop
# ==========================================
while true; do
    header
    echo -e "  ${GREEN}1)${NC} Buat Akun Premium   ${GREEN}5)${NC} Daftar Akun"
    echo -e "  ${GREEN}2)${NC} Buat Akun Trial     ${GREEN}6)${NC} Hapus Expired"
    echo -e "  ${GREEN}3)${NC} Hapus Akun          ${GREEN}7)${NC} Restart ZiVPN"
    echo -e "  ${GREEN}4)${NC} Ganti Domain        ${GREEN}8)${NC} Speedtest"
    echo -e "  ${RED}0) Keluar${NC}"
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────────┐${NC}"
    read -p "  Pilihan [0-8]: " opt
    case $opt in
        1) create_user ;;
        2) u="tr-$(($RANDOM%900+100))"; useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u; echo "$u:1" | chpasswd; sync_zivpn; echo -e "${GREEN}Trial $u Aktif!${NC}"; sleep 2 ;;
        3) delete_user ;;
        4) header; read -p "  Domain Baru: " d; [[ -n $d ]] && echo "$d" > $DOM_FILE && DOM=$d; sync_zivpn ;;
        5) list_users ;;
        6) now=$(($(date +%s)/86400)); while IFS=: read -r u _ _ _ _ _ _ e _; do [[ -n $e && $now -ge $e && $(id -u $u) -ge 1000 ]] && userdel -f $u; done < /etc/shadow; sync_zivpn; echo "Cleaned!"; sleep 1 ;;
        7) systemctl restart zivpn.service; echo "Restarted."; sleep 1 ;;
        8) header; curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
        0) exit ;;
    esac
done
