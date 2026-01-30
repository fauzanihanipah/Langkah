#!/bin/bash

# Konfigurasi File
CONF="/etc/zivpn/config.json"
DOM_FILE="/etc/zivpn/domain"
MYIP=$(curl -s ifconfig.me)
[[ -f $DOM_FILE ]] && DOM=$(cat $DOM_FILE) || DOM=$MYIP

# Warna
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; NC='\033[0m'

# Fungsi Update Config ZiVPN
sync_ziv() {
    users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print "\""$1"\""}' /etc/passwd | paste -sd, -)
    [[ -z $users ]] && final="\"zi\"" || final="\"zi\", $users"
    sed -i -E "s/\"config\": ?\[.*\]/\"config\": [$final]/g" $CONF
    systemctl restart zivpn.service
}

header() {
    clear
    echo -e "${Y}"
    echo "      ____ "
    echo "     /    \      __"
    echo "    |      |____/  |"
    echo "   _(      )      /  RAWWRR!"
    echo "  |_| ---- |_|---|_|"
    echo -e "${C}┌──────────────────────────────────────────┐${NC}"
    echo -e "${C}│${NC}  ${G}ZIVPN MANAGER PRO${NC} | ${Y}DOM: $DOM${NC}  ${C}│${NC}"
    echo -e "${C}└──────────────────────────────────────────┘${NC}"
}

# Menu Functions
create() {
    header
    read -p " User: " user
    id "$user" &>/dev/null && echo "User exists!" && return
    read -p " Pass: " pass
    read -p " Days: " days
    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    sync_ziv
    echo -e "${G}Success! Account Active.${NC}"
    read -p "Back..."
}

trial() {
    header
    u="tr-$(($RANDOM%900+100))"; p="1"
    useradd -e $(date -d "1 day" +"%Y-%m-%d") -s /bin/false $u
    echo "$u:$p" | chpasswd && sync_ziv
    echo "/usr/sbin/userdel -f $u && systemctl restart zivpn" | at now + 1 hour &>/dev/null
    echo -e "${G}Trial Created: $u (1 Hour)${NC}"
    read -p "Back..."
}

list() {
    header
    printf "${Y}%-12s %-12s %-10s${NC}\n" "USER" "EXP" "STATUS"
    while IFS=: read -r u _ _ _ _ _ _ e _; do
        [[ $(id -u $u) -ge 1000 && $u != "nobody" ]] && \
        printf "%-12s %-12s %-10s\n" "$u" "$(date -d "1970-01-01 $e days" +"%d-%m-%y")" "${G}Active${NC}"
    done < /etc/shadow
    read -p "Back..."
}

set_dom() {
    header
    read -p " Input Domain: " d
    echo "$d" > $DOM_FILE && DOM=$d
    echo "Domain Updated!" && sleep 1
}

# Loop Menu
while true; do
    header
    echo -e " ${C}[1]${NC} Create User   ${C}[4]${NC} Set Domain"
    echo -e " ${C}[2]${NC} Create Trial  ${C}[5]${NC} Delete User"
    echo -e " ${C}[3]${NC} List Users    ${C}[6]${NC} Auto-XP"
    echo -e " ${R}[x] Exit${NC}"
    read -p " Action: " opt
    case $opt in
        1) create ;;
        2) trial ;;
        3) list ;;
        4) set_dom ;;
        5) read -p "User: " u; userdel -f $u; sync_ziv ;;
        6) # Hapus yang expired
           now=$(($(date +%s)/86400))
           while IFS=: read -r u _ _ _ _ _ _ e _; do
               [[ -n $e && $now -ge $e && $(id -u $u) -ge 1000 ]] && userdel -f $u
           done < /etc/shadow
           sync_ziv; echo "XP Cleaned!"; sleep 1 ;;
        x) exit ;;
    esac
done
