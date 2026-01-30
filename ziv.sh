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
NC='\033[0m' # No Color

# ==========================================
# Variabel IP & Domain
# ==========================================
MYIP=$(curl -s ifconfig.me)

# ==========================================
# Fungsi Header
# ==========================================
header() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}             ${PURPLE}ZIVPN MANAGER PREMIUM EDITION${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}             ${YELLOW}     IP: $MYIP${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────┘${NC}"
}

# ==========================================
# 1. Buat Akun (Reguler)
# ==========================================
create_user() {
    header
    echo -e "          ${GREEN}[ BUAT AKUN PREMIUM ]${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "  Masukkan Username : " user
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: User '$user' sudah ada!${NC}"
        read -p "Tekan Enter..."; return
    fi
    read -p "  Masukkan Password : " pass
    read -p "  Masa Aktif (Hari) : " days

    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    header
    echo -e "${GREEN}          AKUN BERHASIL DIBUAT!${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    echo -e "  Host IP    : ${YELLOW}$MYIP${NC}"
    echo -e "  Username   : ${YELLOW}$user${NC}"
    echo -e "  Password   : ${YELLOW}$pass${NC}"
    echo -e "  UDP Port   : ${YELLOW}7100, 7200, 7300${NC}"
    echo -e "  Expired    : ${RED}$(date -d "$days days" +"%d %b %Y")${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    echo -e "  Config : ${CYAN}$user:$pass@$MYIP:22${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# 2. Buat Akun Trial (1 Jam)
# ==========================================
trial_user() {
    header
    echo -e "          ${YELLOW}[ BUAT AKUN TRIAL (1 JAM) ]${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    user="trial$(random_number)"
    pass="trial"
    
    # Trial berlaku 1 jam (menggunakan manipulasi tanggal expire linux)
    # Karena useradd -e hitungannya hari, kita gunakan at/cron untuk hapus otomatis
    exp=$(date -d "1 day" +"%Y-%m-%d") 
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    # Perintah hapus otomatis dalam 60 menit
    echo "userdel -f $user" | at now + 60 minutes &>/dev/null
    
    header
    echo -e "${GREEN}          AKUN TRIAL BERHASIL!${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    echo -e "  Username   : ${YELLOW}$user${NC}"
    echo -e "  Password   : ${YELLOW}$pass${NC}"
    echo -e "  Durasi     : ${RED}60 Menit${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "Tekan Enter..."
}

random_number() {
    echo $((RANDOM % 900 + 100))
}

# ==========================================
# 3. List & Cek Expired
# ==========================================
list_users() {
    header
    echo -e "          ${YELLOW}[ DAFTAR PENGGUNA ZIVPN ]${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    printf "  ${BLUE}%-15s | %-15s | %-10s${NC}\n" "USERNAME" "EXP DATE" "STATUS"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            if [ -z "$exp" ]; then expire="No Limit"; else
                expire=$(date -d "1970-01-01 $exp days" +"%d-%m-%Y")
            fi
            # Logika Status
            now=$(date +%s)
            exp_sec=$((exp * 86400))
            if [ "$now" -ge "$exp_sec" ]; then status="${RED}Expired${NC}"; else status="${GREEN}Active${NC}"; fi
            printf "  %-15s | %-15s | %-10s\n" "$user" "$expire" "$status"
        fi
    done < /etc/shadow
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "Tekan Enter..."
}

# ==========================================
# 4. Hapus Akun
# ==========================================
delete_user() {
    header
    echo -e "          ${RED}[ HAPUS PENGGUNA ]${NC}"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "  Masukkan Username: " user
    if id "$user" &>/dev/null; then
        userdel -f "$user"
        echo -e "${GREEN}  User '$user' telah dihapus!${NC}"
    else
        echo -e "${RED}  User tidak ditemukan!${NC}"
    fi
    read -p "Tekan Enter..."
}

# ==========================================
# 5. Fungsi Auto-Delete (XP)
# ==========================================
auto_xp() {
    now=$(date +%s)
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            if [ -n "$exp" ]; then
                exp_sec=$((exp * 86400))
                if [ "$now" -ge "$exp_sec" ]; then
                    userdel -f "$user"
                fi
            fi
        fi
    done < /etc/shadow
}

# ==========================================
# Main Menu
# ==========================================
while true; do
    header
    echo -e "  ${CYAN}[1]${NC} Buat Akun Premium (Reguler)"
    echo -e "  ${CYAN}[2]${NC} Buat Akun Trial (1 Jam)"
    echo -e "  ${CYAN}[3]${NC} Lihat Daftar Akun & Cek Expired"
    echo -e "  ${CYAN}[4]${NC} Hapus Akun Secara Manual"
    echo -e "  ${CYAN}[5]${NC} Bersihkan Akun Expired (Auto-XP)"
    echo -e "  ${RED}[x]${NC} Keluar"
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    read -p "  Pilih Menu [1-5]: " opt
    case $opt in
        1) create_user ;;
        2) trial_user ;;
        3) list_users ;;
        4) delete_user ;;
        5) auto_xp; echo -e "${GREEN}Sukses membersihkan akun mati!${NC}"; sleep 2 ;;
        x) exit ;;
        *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1 ;;
    esac
done
