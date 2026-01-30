#!/bin/bash

# ==========================================
# Color Definitions
# ==========================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variabel System
MYIP=$(curl -s ifconfig.me)
CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
[[ ! -f $DOMAIN_FILE ]] && echo "N/A" > $DOMAIN_FILE
DOMAIN=$(cat $DOMAIN_FILE)

# Mendapatkan Spek (Sesuai Gambar)
OS_NAME=$(grep -P '^PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10)
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PER=$(awk "BEGIN {printf \"%.0f\", ($RAM_USED/$RAM_TOTAL)*100}")
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PER=$(df -h / | awk 'NR==2 {print $5}')
CPU_MODEL=$(lscpu | grep "Model name" | cut -d ":" -f 2 | sed 's/^[ \t]*//')
UPTIME=$(uptime -p | sed 's/up //')
USERS_COUNT=$(grep -c -E '^[^:]+:[^\!*]' /etc/shadow) # Total Akun

# Check ZiVPN Service Status
check_zivpn_status() {
    systemctl is-active --quiet zivpn.service && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}"
}

header() {
    clear
    # Logo OGH ZIV ASCII (Centered)
    echo -e "${PURPLE}  _  _  ____  ____    ____  ____  _  _ ______  _  _"
    echo -e " | | | |  _ \/ ___|  |___ \/ ___|| || |____  || || |"
    echo -e " | | | | |_) | |  _    __) \___ \| || |   / / | || |"
    echo -e " | |_| |  _ <| |_| |  / __/ ___) | || |  / /  | || |"
    echo -e "  \___/|_| \_\\____| |_____|____/|_||_| /_/   |_||_|"
    echo -e "${NC}"
    
    # Header Line
    echo -e "${YELLOW}╔══════════════════${NC}// PT RAJA SERVER PREMIUM //${YELLOW}══════════════════╗${NC}"
    
    # Info Detail (2 Kolom)
    printf " ${BLUE}%-9s${NC}: ${WHITE}%-18s${NC} ${BLUE}%-7s${NC}: ${WHITE}%-20s${NC}\n" "OS" "$OS_NAME" "ISP" "$ISP"
    printf " ${BLUE}%-9s${NC}: ${WHITE}%-18s${NC} ${BLUE}%-7s${NC}: ${WHITE}%-20s${NC}\n" "IP" "$MYIP" "Host" "$MYIP"
    printf " ${BLUE}%-9s${NC}: ${WHITE}%-18s${NC} ${BLUE}%-7s${NC}: ${WHITE}%-20s${NC}\n" "Client" "N/A" "EXP" "N/A" # Perlu diimplementasi jika ada
    printf " ${BLUE}%-9s${NC}: ${WHITE}0.00 GiB${NC}        ${BLUE}%-7s${NC}: ${WHITE}0.00 GiB${NC}\n" "Today" "Month" # Perlu implementasi traffic
    printf " ${BLUE}%-9s${NC}: ${WHITE}%sMi/%sMi (%s%%)${NC}  ${BLUE}%-7s${NC}: ${WHITE}%s/%s (%s)${NC}\n" "RAM" "$RAM_USED" "$RAM_TOTAL" "$RAM_PER" "Disk" "$DISK_USED" "$DISK_TOTAL" "$DISK_PER"
    printf " ${BLUE}%-9s${NC}: ${WHITE}%s${NC}\n" "CPU" "$CPU_MODEL"
    printf " ${BLUE}%-9s${NC}: ${WHITE}up %s${NC}\n" "Uptime" "$UPTIME"
    printf " ${BLUE}%-9s${NC}: ${WHITE}%s${NC}\n" "Users" "$USERS_COUNT"
    printf " ${BLUE}%-9s${NC}: ${WHITE}v$(date +%Y.%m.%d)${NC}\n" "Version"
    
    echo -e "${YELLOW}╚═════════════════════════════════════════════════════════════════╝${NC}"
    
    # Service Status
    echo -e "                 ${BLUE}ZiVPN:${NC} $(check_zivpn_status)"
    echo -e "                 ${BLUE}ZiVPN API:${NC} ${RED}Unknown${NC}" # Status API ZiVPN jika ada
    echo ""
}

sync_zivpn() {
    echo -e "${YELLOW} [!] Sinkronisasi Konfigurasi ZiVPN...${NC}"
    # Ambil semua password dari user yang expired-nya masih aktif
    passwords=$(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f1 | xargs -I {} grep -E "^{}:" /etc/shadow | awk -F: '$8 > (strftime("%s")/86400) || $8 == "" {print $1}' | xargs -I {} grep "^{}:" /etc/passwd | cut -d: -f1)
    
    # Tambahkan password default 'zi' jika ada dan buat daftar final
    final_pass="\"zi\"" # Default password jika ada
    for p in $passwords; do
        final_pass="$final_pass, \"$p\""
    done

    # Masukkan ke config.json
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final_pass]/g" $CONFIG_FILE
    
    # Restart Layanan ZiVPN
    systemctl restart zivpn.service &>/dev/null
    echo -e "${GREEN} [✓] Konfigurasi ZiVPN Berhasil Diperbarui!${NC}"
    sleep 1
}

create_user() {
    header
    echo -e "  ${BLUE}╔═══════════════════[ BUAT AKUN PREMIUM ]═══════════════════╗${NC}"
    read -p "  ${WHITE}Username    : ${NC}" user
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: Username sudah ada!${NC}"; sleep 2; return
    fi
    read -p "  ${WHITE}Password    : ${NC}" pass
    read -p "  ${WHITE}Masa Aktif (Hari) : ${NC}" days

    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    sync_zivpn

    clear
    header
    echo -e "  ${GREEN}╔════════════════════[ AKUN BERHASIL DIBUAT ]════════════════════╗${NC}"
    printf "  ${WHITE}║ %-56s %s${NC}\n" "" "║"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${YELLOW}%-38s${NC} ${WHITE}║${NC}\n" "Username" "$user"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${YELLOW}%-38s${NC} ${WHITE}║${NC}\n" "Password" "$pass"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${CYAN}%-38s${NC} ${WHITE}║${NC}\n" "IP VPS" "$MYIP"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${CYAN}%-38s${NC} ${WHITE}║${NC}\n" "Domain" "$DOMAIN"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${RED}%-38s${NC} ${WHITE}║${NC}\n" "Expired Pada" "$(date -d "$days days" +"%d %b %Y")"
    printf "  ${WHITE}║ %-56s %s${NC}\n" "" "║"
    echo -e "  ${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "  Tekan Enter untuk kembali ke menu..."
}

delete_user() {
    header
    echo -e "  ${RED}╔══════════════════[ HAPUS AKUN PENGGUNA ]═══════════════════╗${NC}"
    read -p "  ${WHITE}Masukkan Username yang akan dihapus: ${NC}" user_to_delete

    if id "$user_to_delete" &>/dev/null; then
        user_pass=$(grep "^$user_to_delete:" /etc/shadow | cut -d: -f2) # Ambil password hash
        user_exp_days=$(grep "^$user_to_delete:" /etc/shadow | cut -d: -f8)
        user_exp_date=$(date -d "1970-01-01 $user_exp_days days" +"%d %b %Y")

        echo -e "  ${YELLOW}Detail Akun:${NC}"
        echo -e "  ${BLUE}Username   :${NC} ${WHITE}$user_to_delete${NC}"
        echo -e "  ${BLUE}Password (hash):${NC} ${WHITE}$user_pass${NC}"
        echo -e "  ${BLUE}Expired    :${NC} ${WHITE}$user_exp_date${NC}"
        echo ""
        read -p "  ${RED}Anda yakin ingin menghapus akun ini? (y/n): ${NC}" confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            userdel -f "$user_to_delete"
            sync_zivpn
            echo -e "${GREEN}  Akun ${user_to_delete} berhasil dihapus!${NC}"
        else
            echo -e "${YELLOW}  Penghapusan dibatalkan.${NC}"
        fi
    else
        echo -e "${RED}  Error: Username tidak ditemukan!${NC}"
    fi
    echo -e "  ${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    sleep 2
}

list_users() {
    header
    echo -e "  ${BLUE}╔════════════════════[ DAFTAR AKUN AKTIF ]════════════════════╗${NC}"
    printf "  ${WHITE}║ %-3s %-15s %-15s %-10s %s${NC}\n" "No." "Username" "Exp. Date" "Status" "║"
    echo -e "  ${WHITE}╠════════════════════════════════════════════════════════════╣${NC}"
    
    i=1
    while IFS=: read -r user _ _ _ _ _ _ exp_days _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            exp_date=$(date -d "1970-01-01 $exp_days days" +"%d %b %Y")
            current_days=$(date +%s)/86400
            
            if [ "$exp_days" -ge "$current_days" ] || [ -z "$exp_days" ]; then
                status="${GREEN}AKTIF${NC}"
            else
                status="${RED}EXPIRED${NC}"
            fi
            printf "  ${WHITE}║ %-3s ${YELLOW}%-15s${NC} ${CYAN}%-15s${NC} %-10s ${WHITE}║${NC}\n" "$i" "$user" "$exp_date" "$status"
            ((i++))
        fi
    done < /etc/shadow
    echo -e "  ${WHITE}╚════════════════════════════════════════════════════════════╣${NC}"
    read -p "  Tekan Enter untuk kembali ke menu..."
}

change_domain() {
    header
    echo -e "  ${BLUE}╔══════════════════[ KONFIGURASI DOMAIN ]═══════════════════╗${NC}"
    echo -e "  ${WHITE}Domain Saat Ini : ${CYAN}$DOMAIN${NC}"
    read -p "  ${WHITE}Masukkan Domain Baru: ${NC}" new_dom
    if [[ -z "$new_dom" ]]; then
        echo -e "${RED}  Domain tidak boleh kosong!${NC}"; sleep 2; return
    fi
    echo "$new_dom" > $DOMAIN_FILE
    DOMAIN=$new_dom
    echo -e "${GREEN}  Domain berhasil diperbarui menjadi ${CYAN}$DOMAIN${NC}!${NC}"
    echo -e "  ${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    sleep 2
}

trial_user() {
    header
    echo -e "  ${BLUE}╔═══════════════════[ BUAT AKUN TRIAL 1 JAM ]═══════════════════╗${NC}"
    local user="trial$((RANDOM % 9000 + 1000))"
    local pass="trial"
    local exp_date=$(date -d "1 hour" +"%Y-%m-%d %H:%M:%S")

    useradd -e "$(date -d "1 hour" +"%Y-%m-%d")" -s /bin/false "$user"
    echo "$user:$pass" | chpasswd
    
    sync_zivpn

    # Schedule deletion after 1 hour
    (sleep 3600; userdel -f "$user" &>/dev/null; sync_zivpn &>/dev/null) & disown

    clear
    header
    echo -e "  ${GREEN}╔════════════════════[ AKUN TRIAL DIBUAT ]═════════════════════╗${NC}"
    printf "  ${WHITE}║ %-56s %s${NC}\n" "" "║"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${YELLOW}%-38s${NC} ${WHITE}║${NC}\n" "Username" "$user"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${YELLOW}%-38s${NC} ${WHITE}║${NC}\n" "Password" "$pass"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${CYAN}%-38s${NC} ${WHITE}║${NC}\n" "IP VPS" "$MYIP"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${CYAN}%-38s${NC} ${WHITE}║${NC}\n" "Domain" "$DOMAIN"
    printf "  ${WHITE}║ ${BLUE}%-15s${NC} : ${RED}%-38s${NC} ${WHITE}║${NC}\n" "Expired Pada" "$exp_date (dalam 1 jam)"
    printf "  ${WHITE}║ %-56s %s${NC}\n" "" "║"
    echo -e "  ${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "  Tekan Enter untuk kembali ke menu..."
}

# Fungsi Dummy (untuk menu yang belum diimplementasikan)
coming_soon() {
    header
    echo -e "${YELLOW}  Fitur ini akan segera hadir!${NC}"
    sleep 1
}

# --- Main Menu Loop ---
while true; do
    header
    echo -e "  ${YELLOW}┌──────────────────────────────────────────┐${NC}"
    echo -e "  ${YELLOW}│${NC}                                          ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 1)${NC} Create Account                       ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 2)${NC} Create Trial Account                 ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 3)${NC} Delete Account                       ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 4)${NC} Change Domain                        ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 5)${NC} List Accounts                        ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 6)${NC} Backup/Restore                       ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 7)${NC} Generate API Auth Key                ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 8)${NC} View API Auth Key                    ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 9)${NC} Restart Service                      ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE}10)${NC} Update Script Version                ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE}11)${NC} Update License Expiry                ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE}12)${NC} Speedtest Server                     ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE}13)${NC} Fix Error ZIVPN                      ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${BLUE} 0)${NC} Exit                                 ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}                                          ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}└──────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne " ${GREEN}Enter your choice [0-13]: ${NC}"
    read opt
    case $opt in
        1) create_user ;;
        2) trial_user ;;
        3) delete_user ;;
        4) change_domain ;;
        5) list_users ;;
        6) coming_soon ;; # Dummy for Backup/Restore
        7) coming_soon ;; # Dummy for Generate API Key
        8) coming_soon ;; # Dummy for View API Key
        9) systemctl restart zivpn.service && echo -e "${GREEN}  ZiVPN Service berhasil direstart!${NC}" || echo -e "${RED}  Gagal merestart ZiVPN Service.${NC}"; sleep 2 ;;
        10) coming_soon ;; # Dummy for Update Script Version
        11) coming_soon ;; # Dummy for Update License Expiry
        12) coming_soon ;; # Dummy for Speedtest
        13) coming_soon ;; # Dummy for Fix Error
        0) echo -e "${YELLOW}  Keluar dari ZiVPN Manager...${NC}"; exit ;;
        *) echo -e "${RED}  Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
done
