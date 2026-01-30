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

# Variables
MYIP=$(curl -s ifconfig.me)
CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
[[ ! -f $DOMAIN_FILE ]] && echo "NOT_SET" > $DOMAIN_FILE
DOMAIN=$(cat $DOMAIN_FILE)

# System Specs
OS_NAME=$(grep -P '^PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
CPU_CORE=$(nproc)
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
UPTIME=$(uptime -p | sed 's/up //')

header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}       ${PURPLE}██████╗      ██████╗     ██╗  ██╗${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${PURPLE}██╔═══██╗    ██╔════╝     ██║  ██║${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${PURPLE}██║   ██║    ██║  ███╗    ███████║${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${PURPLE}██║   ██║    ██║   ██║    ██╔══██║${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${PURPLE}╚██████╔╝    ╚██████╔╝    ██║  ██║${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}       ${PURPLE}╚═════╝      ╚═════╝     ╚═╝  ╚═╝${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}OS      :${NC}  ${WHITE}$OS_NAME${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}CPU/RAM :${NC}  ${WHITE}$CPU_CORE Core / $RAM_TOTAL MB${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}UPTIME  :${NC}  ${WHITE}$UPTIME${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}IP VPS  :${NC}  ${YELLOW}$MYIP${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}DOMAIN  :${NC}  ${GREEN}$DOMAIN${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
}

# Fungsi Sinkronisasi
sync_zivpn() {
    echo -e "${YELLOW} [!] Updating ZiVPN Config...${NC}"
    passwords=$(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f1 | xargs -I {} grep -E "^{}:" /etc/shadow | awk -F: '$8 > (strftime("%s")/86400) || $8 == "" {print $1}' | xargs -I {} grep "^{}:" /etc/passwd | cut -d: -f1)
    final_pass="\"zi\""
    for p in $passwords; do final_pass="$final_pass, \"$p\""; done
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final_pass]/g" $CONFIG_FILE
    systemctl restart zivpn.service &>/dev/null
    echo -e "${GREEN} [✓] Done!${NC}"
}

# --- Main Menu Loop ---
while true; do
    header
    echo -e "${CYAN}║${NC}  ${YELLOW}[01]${NC} Create Account    ${CYAN}║${NC}  ${YELLOW}[04]${NC} Delete Account    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[02]${NC} Create Trial      ${CYAN}║${NC}  ${YELLOW}[05]${NC} Set Domain        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[03]${NC} User List         ${CYAN}║${NC}  ${YELLOW}[06]${NC} Clear Expired     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${RED}[xx]${NC} ${WHITE}EXIT MANAGER CONNECTION${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -ne "  ${YELLOW}Select Action » ${NC}"
    read opt
    case $opt in
        1|01) 
            header
            read -p "  Username: " user
            read -p "  Password: " pass
            read -p "  Active Days: " days
            exp=$(date -d "$days days" +"%Y-%m-%d")
            useradd -e $exp -s /bin/false $user
            echo "$user:$pass" | chpasswd
            sync_zivpn
            read -p "  Success! Press Enter..."
            ;;
        2|02) # Tambahkan fungsi trial di sini
            ;;
        3|03) # Tambahkan fungsi list di sini
            ;;
        4|04) # Tambahkan fungsi delete di sini
            ;;
        5|05)
            header
            read -p "  New Domain: " new_dom
            echo "$new_dom" > $DOMAIN_FILE
            DOMAIN=$new_dom
            echo -e "  Domain Saved!"
            sleep 1
            ;;
        6|06) /usr/bin/xp; sync_zivpn; echo "Cleaned!"; sleep 2 ;;
        x|xx) exit ;;
        *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
