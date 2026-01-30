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

# Ensure Domain File Exists
[[ ! -f $DOMAIN_FILE ]] && echo "Not_Set" > $DOMAIN_FILE
DOMAIN=$(cat $DOMAIN_FILE)

header() {
    clear
    echo -e "${PURPLE}"
    echo -e "  ██████╗  ██████╗ ██╗  ██╗"
    echo -e " ██╔═══██╗██╔════╝ ██║  ██║"
    echo -e " ██║   ██║██║  ███╗███████║"
    echo -e " ██║   ██║██║   ██║██╔══██║"
    echo -e " ╚██████╔╝╚██████╔╝██║  ██║"
    echo -e "  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
    echo -e " ${CYAN}      PREMIUM VPN MANAGER${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}IP     :${NC} ${YELLOW}$MYIP${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}DOMAIN :${NC} ${GREEN}$DOMAIN${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────┘${NC}"
}

sync_zivpn() {
    echo -e "${YELLOW}Syncing configurations...${NC}"
    passwords=$(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f1 | xargs -I {} grep -E "^{}:" /etc/shadow | awk -F: '$8 > (strftime("%s")/86400) || $8 == "" {print $1}' | xargs -I {} grep "^{}:" /etc/passwd | cut -d: -f1)
    
    final_pass="\"zi\""
    for p in $passwords; do
        final_pass="$final_pass, \"$p\""
    done

    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final_pass]/g" $CONFIG_FILE
    systemctl restart zivpn.service &>/dev/null
    echo -e "${GREEN}System Synchronized!${NC}"
}

add_domain() {
    header
    echo -e " ${BLUE}[ SET DOMAIN VPS ]${NC}"
    echo -e " Current: $DOMAIN"
    echo -e ""
    read -p " Enter New Domain: " new_dom
    if [[ -z "$new_dom" ]]; then
        echo -e "${RED}Domain cannot be empty!${NC}"; sleep 2; return
    fi
    echo "$new_dom" > $DOMAIN_FILE
    DOMAIN=$new_dom
    echo -e "${GREEN}Domain updated successfully!${NC}"
    read -p " Press Enter..."
}

create_user() {
    header
    echo -e " ${BLUE}[ CREATE PREMIUM ACCOUNT ]${NC}"
    echo ""
    read -p "  Username : " user
    if id "$user" &>/dev/null; then
        echo -e "${RED}  Error: User already exists!${NC}"; read -p "Enter..."; return
    fi
    read -p "  Password : " pass
    read -p "  Active Days: " days

    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    sync_zivpn

    header
    echo -e "${GREEN}      ACCOUNT CREATED SUCCESSFULLY!${NC}"
    echo -e " ${WHITE}──────────────────────────────────────────${NC}"
    echo -e "  Username : ${YELLOW}$user${NC}"
    echo -e "  Password : ${YELLOW}$pass${NC}"
    echo -e "  Domain   : ${CYAN}$DOMAIN${NC}"
    echo -e "  Expired  : ${RED}$(date -d "$days days" +"%d %b %Y")${NC}"
    echo -e " ${WHITE}──────────────────────────────────────────${NC}"
    read -p " Press Enter..."
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
    
    echo -e "${GREEN}Trial Account Created (1 Hour): $user${NC}"
    read -p "Enter..."
}

list_users() {
    header
    echo -e " ${WHITE}ID   USERNAME        EXP DATE        STATUS${NC}"
    echo -e " ──────────────────────────────────────────"
    i=1
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            expire=$(date -d "1970-01-01 $exp days" +"%d-%m-%Y")
            printf " [%02d] %-15s %-15s %b\n" "$i" "$user" "$expire" "${GREEN}Active${NC}"
            ((i++))
        fi
    done < /etc/shadow
    echo -e " ──────────────────────────────────────────"
    read -p " Press Enter..."
}

delete_user() {
    header
    read -p "  Username to delete: " user
    if id "$user" &>/dev/null; then
        userdel -f "$user"
        sync_zivpn
        echo -e "${GREEN}User $user deleted!${NC}"
    else
        echo -e "${RED}User not found!${NC}"
    fi
    read -p " Press Enter..."
}

# Main Menu
while true; do
    header
    echo -e "  ${CYAN}[01]${NC} ${WHITE}Create Premium Account${NC}"
    echo -e "  ${CYAN}[02]${NC} ${WHITE}Create Trial Account${NC}"
    echo -e "  ${CYAN}[03]${NC} ${WHITE}List Active Users${NC}"
    echo -e "  ${CYAN}[04]${NC} ${WHITE}Delete User Account${NC}"
    echo -e "  ${CYAN}[05]${NC} ${WHITE}Set Domain VPS${NC}"
    echo -e "  ${CYAN}[06]${NC} ${WHITE}Clear Expired Users${NC}"
    echo -e "  ${PURPLE}[xx]${NC} ${WHITE}Exit Program${NC}"
    echo -e ""
    echo -ne "  ${YELLOW}Select Option » ${NC}"
    read opt
    case $opt in
        1|01) create_user ;;
        2|02) trial_user ;;
        3|03) list_users ;;
        4|04) delete_user ;;
        5|05) add_domain ;;
        6|06) /usr/bin/xp; sync_zivpn; echo "Cleaned!"; sleep 2 ;;
        x|xx) exit ;;
        *) echo -e "${RED}Invalid Option!${NC}"; sleep 1 ;;
    esac
done
