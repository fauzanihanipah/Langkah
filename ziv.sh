#!/bin/bash

# ==========================================
# Color Definitions (Premium Palette)
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

# Count Active Users
count_active() {
    # Menghitung user yang sedang login via SSH (bisa disesuaikan dengan port ZiVPN)
    users_online=$(netstat -anp | grep ESTABLISHED | grep sshd | cut -d ":" -f 2 | cut -d " " -f 12 | sort | uniq | wc -l)
    echo "$users_online"
}

header() {
    clear
    ACTIVE_USER=$(count_active)
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${PURPLE}██████╗      ██████╗     ██╗  ██╗${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${PURPLE}██╔═══██╗    ██╔════╝     ██║  ██║${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${PURPLE}██║   ██║    ██║  ███╗    ███████║${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${PURPLE}██║   ██║    ██║   ██║    ██╔══██║${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${PURPLE}╚██████╔╝    ╚██████╔╝    ██║  ██║${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${PURPLE}╚═════╝      ╚═════╝     ╚═╝  ╚═╝${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  ${BLUE}%-14s${NC} : ${WHITE}%-34s${NC}  ${CYAN}║${NC}\n" "OS" "$OS_NAME"
    printf "${CYAN}║${NC}  ${BLUE}%-14s${NC} : ${WHITE}%-34s${NC}  ${CYAN}║${NC}\n" "CPU/RAM" "$CPU_CORE Core / $RAM_TOTAL MB"
    printf "${CYAN}║${NC}  ${BLUE}%-14s${NC} : ${WHITE}%-34s${NC}  ${CYAN}║${NC}\n" "IP/DOMAIN" "$MYIP / $DOMAIN"
    printf "${CYAN}║${NC}  ${BLUE}%-14s${NC} : ${GREEN}%-34s${NC}  ${CYAN}║${NC}\n" "STATUS" "Online ($ACTIVE_USER Users Active)"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
}

sync_zivpn() {
    echo -e "${YELLOW} [!] Syncing ZiVPN Configuration...${NC}"
    passwords=$(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f1 | xargs -I {} grep -E "^{}:" /etc/shadow | awk -F: '$8 > (strftime("%s")/86400) || $8 == "" {print $1}' | xargs -I {} grep "^{}:" /etc/passwd | cut -d: -f1)
    final_pass="\"zi\""
    for p in $passwords; do final_pass="$final_pass, \"$p\""; done
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final_pass]/g" $CONFIG_FILE
    systemctl restart zivpn.service &>/dev/null
    echo -e "${GREEN} [✓] Database Updated Successfully!${NC}"
}

create_user() {
    header
    echo -e "  ${PURPLE}REGISTER NEW PREMIUM ACCOUNT${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────${NC}"
    read -p "   Username : " user
    if id "$user" &>/dev/null; then echo -e "${RED}   User already exists!${NC}"; sleep 2; return; fi
    read -p "   Password : " pass
    read -p "   Duration : " days
    
    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    sync_zivpn

    # Elegant Success Receipt
    clear
    header
    echo -e "  ${GREEN}╔══════════[ ACCOUNT CREATED ]═══════════╗${NC}"
    echo -e "  ${WHITE}   User      : ${YELLOW}$user${NC}"
    echo -e "  ${WHITE}   Pass      : ${YELLOW}$pass${NC}"
    echo -e "  ${WHITE}   IP VPS    : ${CYAN}$MYIP${NC}"
    echo -e "  ${WHITE}   Domain    : ${CYAN}$DOMAIN${NC}"
    echo -e "  ${WHITE}   Expired   : ${RED}$(date -d "$days days" +"%d %b %Y")${NC}"
    echo -e "  ${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    read -p "  Press Enter to Return..."
}

delete_user() {
    header
    echo -e "  ${RED}TERMINATE USER ACCOUNT${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────${NC}"
    read -p "   Enter Username to Delete: " user
    if id "$user" &>/dev/null; then
        echo -e "   ${YELLOW}Found!${NC} Account ${WHITE}$user${NC} will be deleted."
        read -p "   Confirm Delete? (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            userdel -f "$user"
            sync_zivpn
            echo -e "${GREEN}   Account $user has been wiped!${NC}"
        else
            echo -e "${YELLOW}   Deletion Cancelled.${NC}"
        fi
    else
        echo -e "${RED}   Error: User not found!${NC}"
    fi
    sleep 2
}

while true; do
    header
    echo -e "${CYAN}║${NC}  ${YELLOW}[01]${NC} Create Premium      ${CYAN}║${NC}  ${YELLOW}[04]${NC} Delete Account      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[02]${NC} Create Trial        ${CYAN}║${NC}  ${YELLOW}[05]${NC} Configure Domain    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[03]${NC} User List           ${CYAN}║${NC}  ${YELLOW}[06]${NC} Wipe Expired        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}[xx]${NC} ${WHITE}EXIT FROM CONNECTION MANAGER${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -ne "  ${YELLOW}Select Option » ${NC}"
    read opt
    case $opt in
        1|01) create_user ;;
        2|02) # Tambahkan fungsi trial di sini jika perlu
              echo "Coming Soon"; sleep 1 ;;
        3|03) # Tambahkan fungsi list_users di sini
              echo "Coming Soon"; sleep 1 ;;
        4|04) delete_user ;;
        5|05)
            header
            read -p "  Enter New Domain: " new_dom
            echo "$new_dom" > $DOMAIN_FILE
            DOMAIN=$new_dom
            echo -e "  Domain Updated!"
            sleep 1 ;;
        6|06) /usr/bin/xp; sync_zivpn; sleep 2 ;;
        x|xx) exit ;;
        *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
