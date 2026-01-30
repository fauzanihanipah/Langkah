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

# Variabel
MYIP=$(curl -s ifconfig.me)
CONFIG_FILE="/etc/zivpn/config.json"

header() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}             ${PURPLE}ZIVPN MANAGER FIX CONNECTION${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}               ${YELLOW}IP: $MYIP${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────┘${NC}"
}

# Fungsi Update Config ZiVPN (PENTING AGAR KONEK)
sync_zivpn() {
    # Ambil semua password dari user yang expired-nya masih aktif
    passwords=$(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f1 | xargs -I {} grep -E "^{}:" /etc/shadow | awk -F: '$8 > (strftime("%s")/86400) || $8 == "" {print $1}' | xargs -I {} grep "^{}:" /etc/passwd | cut -d: -f1)
    
    # Tambahkan password default 'zi'
    final_pass="\"zi\""
    for p in $passwords; do
        final_pass="$final_pass, \"$p\""
    done

    # Masukkan ke config.json
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final_pass]/g" $CONFIG_FILE
    
    # Restart Layanan ZiVPN
    systemctl restart zivpn.service
}

create_user() {
    header
    echo -e "          ${GREEN}[ BUAT AKUN PREMIUM ]${NC}"
    line
    read -p "  Username : " user
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: User sudah ada!${NC}"; read -p "Enter..."; return
    fi
    read -p "  Password (Gunakan untuk login di App): " pass
    read -p "  Masa Aktif (Hari): " days

    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    # Sinkronisasi agar bisa konek
    sync_zivpn

    header
    echo -e "${GREEN}          AKUN BERHASIL & AKTIF!${NC}"
    echo -e "  Username : ${YELLOW}$user${NC}"
    echo -e "  Password : ${YELLOW}$pass${NC}"
    echo -e "  Expired  : ${RED}$(date -d "$days days" +"%d %b %Y")${NC}"
    echo -e "  Status   : ${GREEN}Koneksi ZiVPN Aktif${NC}"
    read -p "Tekan Enter..."
}

trial_user() {
    header
    user="trial$((RANDOM % 900 + 100))"
    pass="trial"
    exp=$(date -d "1 day" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    sync_zivpn
    echo "userdel -f $user; /usr/bin/zivpn-sync" | at now + 60 minutes &>/dev/null
    
    echo -e "${GREEN}Akun Trial 1 Jam Dibuat: $user${NC}"
    read -p "Enter..."
}

list_users() {
    header
    printf "  %-15s | %-15s | %-10s\n" "USERNAME" "EXP DATE" "STATUS"
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            expire=$(date -d "1970-01-01 $exp days" +"%d-%m-%Y")
            echo -e "  $user \t $expire"
        fi
    done < /etc/shadow
    read -p "Enter..."
}

delete_user() {
    header
    read -p "  Username dihapus: " user
    userdel -f "$user"
    sync_zivpn
    echo -e "${GREEN}User dihapus & Config diupdate!${NC}"
    read -p "Enter..."
}

auto_xp() {
    # Logika hapus user expired
    /usr/bin/xp # Memanggil script xp yang kita buat sebelumnya
    sync_zivpn
}

# Menu Utama
while true; do
    header
    echo -e "  [1] Buat Akun Premium"
    echo -e "  [2] Buat Akun Trial"
    echo -e "  [3] Lihat Daftar Akun"
    echo -e "  [4] Hapus Akun"
    echo -e "  [5] Bersihkan Expired"
    echo -e "  [x] Keluar"
    read -p "  Pilih: " opt
    case $opt in
        1) create_user ;;
        2) trial_user ;;
        3) list_users ;;
        4) delete_user ;;
        5) auto_xp; echo "Cleaned!"; sleep 2 ;;
        x) exit ;;
    esac
done
