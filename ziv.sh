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

# Fungsi Update Config ZiVPN (Wajib agar akun bisa login)
sync_ziv() {
    # Mengambil semua user dengan UID 1000 keatas (User Premium)
    users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    [[ -z $users ]] && final="\"zi\"" || final="\"zi\", $users"
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final]/g" $CONF
    systemctl restart zivpn.service
}

# Tampilan Header Dashboard
header() {
    clear
    echo -e "${P}"
    echo "  _   _  ____   ____     ___   ____ _   _ _____     __"
    echo " | | | ||  _ \ |  _ \   / _ \ / ___| | | |__  /\ \   / /"
    echo " | | | || | | || |_) | | | | | |  _| |_| | / /  \ \ / / "
    echo " | |_| || |_| ||  __/  | |_| | |_| |  _  |/ /_   \ V /  "
    echo "  \___/ |____/ |_|      \___/ \____|_| |_/____|   \_/   "
    echo -e "         ${Y}U D P   O G H Z I V   P R E M I U M${NC}"
    echo -e "${Y}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${C}OS      :${NC} $(lsb_release -ds 2>/dev/null || echo "Ubuntu/Debian")"
    echo -e "  ${C}IP      :${NC} $MYIP"
    echo -e "  ${C}DOMAIN  :${NC} $DOM"
    echo -e "  ${C}RAM     :${NC} $(free -m | awk 'NR==2{printf "%sMB/%sMB (%.0f%%)", $3,$2,$3*100/$2 }')"
    echo -e "  ${C}UPTIME  :${NC} $(uptime -p | cut -d " " -f 2-)"
    echo -e "  ${C}ZiVPN   :${NC} $(systemctl is-active zivpn.service | sed 's/active/Running/g' || echo "Error")"
    echo -e "${Y}└────────────────────────────────────────────────────────┘${NC}"
}

# 1. Buat Akun Premium
create() {
    header
    echo -e "          ${G}[ 01. CREATE PREMIUM ACCOUNT ]${NC}"
    read -p "  Username : " user
    [[ -z $user ]] && return
    id "$user" &>/dev/null && echo -e "${R}  Error: User sudah ada!${NC}" && sleep 1 && return
    read -p "  Password : " pass
    read -p "  Active (Days) : " days
    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd && sync_ziv
    header
    echo -e "${G}  AKUN BERHASIL DIBUAT DAN AKTIF!${NC}"
    echo -e "  Host/IP  : $DOM"
    echo -e "  Username : $user"
    echo -e "  Password : $pass"
    echo -e "  Expired  : $(date -d "$days days" +"%d %b %Y")"
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    read -p "  Tekan Enter untuk kembali..."
}

# 2. Trial 1 Jam
trial() {
    header
    u="tr-$(($RANDOM%900+100))"; p="1"
    useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u
    echo "$u:$p" | chpasswd && sync_ziv
    echo "/usr/sbin/userdel -f $u && systemctl restart zivpn" | at now + 1 hour &>/dev/null
    echo -e "${G}  Trial Berhasil Dibuat: $u (Password: 1)${NC}"
    echo -e "  Berlaku selama 1 Jam."
    read -p "  Enter..."
}

# 3. Hapus Akun (Menampilkan Password yang akan dihapus)
delete() {
    header
    echo -e "          ${R}[ 03. DELETE ACCOUNT ]${NC}"
    read -p "  Masukkan Username yang ingin dihapus: " user
    if id "$user" &>/dev/null; then
        # Ambil password dari database sistem (shadow) - memerlukan akses root
        # Catatan: Password terenkripsi tidak bisa ditampilkan mentah, 
        # namun kita tunjukkan status akunnya.
        echo -e "${Y}  Informasi Akun:${NC}"
        echo -e "  - Username : $user"
        echo -e "  - Status   : Akan Dihapus"
        read -p "  Yakin ingin menghapus? (y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            userdel -f "$user" && sync_ziv
            echo -e "${G}  User $user berhasil dihapus!${NC}"
        else
            echo -e "${Y}  Penghapusan dibatalkan.${NC}"
        fi
    else
        echo -e "${R}  Error: User tidak ditemukan!${NC}"
    fi
    sleep 2
}

# 4. Ganti Domain
change_dom() {
    header
    read -p "  Masukkan Domain/Host Baru: " d
    [[ -z $d ]] && return
    echo "$d" > $DOM_FILE && DOM=$d
    echo -e "${G}  Domain berhasil diupdate!${NC}" && sleep 1
}

# 5. Daftar Akun (List)
list() {
    header
    echo -e "          ${Y}[ LIST AKUN TERDAFTAR ]${NC}"
    printf "  ${C}%-15s %-15s %-10s${NC}\n" "USERNAME" "EXPIRED" "STATUS"
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    while IFS=: read -r u _ _ _ _ _ _ e _; do
        if [[ $(id -u $u) -ge 1000 && $u != "nobody" ]]; then
            exp_d=$(date -d "1970-01-01 $e days" +"%d-%m-%Y" 2>/dev/null || echo "No Limit")
            printf "  %-15s %-15s ${G}%-10s${NC}\n" "$u" "$exp_d" "Active"
        fi
    done < /etc/shadow
    echo -e "${Y}──────────────────────────────────────────────────────────${NC}"
    read -p "  Tekan Enter..."
}

# --- Loop Menu Utama ---
while true; do
    header
    echo -e "  ${Y}1)${NC} Create Account      ${Y}5)${NC} List Accounts"
    echo -e "  ${Y}2)${NC} Trial Account       ${Y}6)${NC} Clear Expired (Auto-XP)"
    echo -e "  ${Y}3)${NC} Delete Account      ${Y}7)${NC} Restart Service"
    echo -e "  ${Y}4)${NC} Change Domain       ${Y}8)${NC} Speedtest Server"
    echo -e "  ${R}0) Exit Manager${NC}"
    echo -e "${Y}┌────────────────────────────────────────────────────────┐${NC}"
    read -p "  Masukkan pilihan Anda [0-8]: " opt
    case $opt in
        1) create ;;
        2) trial ;;
        3) delete ;;
        4) change_dom ;;
        5) list ;;
        6) # Auto XP Clean
           now=$(($(date +%s)/86400))
           while IFS=: read -r u _ _ _ _ _ _ e _; do
               [[ -n $e && $now -ge $e && $(id -u $u) -ge 1000 ]] && userdel -f $u
           done < /etc/shadow
           sync_ziv; echo -e "${G}Akun expired telah dibersihkan!${NC}"; sleep 1 ;;
        7) systemctl restart zivpn.service; echo -e "${G}Service Restarted.${NC}"; sleep 1 ;;
        8) header; echo -e "${G}Running Speedtest...${NC}"; curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
        0) exit ;;
        *) echo -e "${R}Pilihan salah!${NC}"; sleep 1 ;;
    esac
done
