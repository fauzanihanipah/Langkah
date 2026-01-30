#!/bin/bash
# Zivpn UDP Module installer + Manager Premium
# Creator Zahid Islam | Modded for Management

# Warna
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Update & Install Core (Bagian Installer Anda)
echo -e "${CYAN}Updating server...${NC}"
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "${CYAN}Downloading UDP Service...${NC}"
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir -p /etc/zivpn
wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

# Sertifikat & Sysctl
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=CA/L=LA/O=Zivpn/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# Systemd Service
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
EOF

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

# Firewall & Iptables
ETH=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $ETH -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

# ==========================================
# FUNGSI MANAGEMENT (FITUR BARU)
# ==========================================

# 1. Tambah Domain
add_domain() {
    read -p "Masukkan Domain/Subdomain Anda: " domain
    echo "$domain" > /etc/zivpn/domain
    echo -e "${GREEN}Domain $domain berhasil disimpan!${NC}"
}

# 2. Buat Akun (Create)
create_user() {
    read -p "Username: " user
    read -p "Password: " pass
    read -p "Masa Aktif (Hari): " days
    
    exp=$(date -d "$days days" +"%Y-%m-%d")
    useradd -e $exp -s /bin/false $user
    echo "$user:$pass" | chpasswd
    
    DOMAIN=$(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)
    
    clear
    echo -e "${PURPLE}─── AKUN ZIVPN UDP BERHASIL ───${NC}"
    echo -e "Domain/IP : $DOMAIN"
    echo -e "Username  : $user"
    echo -e "Password  : $pass"
    echo -e "Port UDP  : 6000-19999"
    echo -e "Expired   : $(date -d "$days days" +"%d %b %Y")"
    echo -e "${PURPLE}───────────────────────────────${NC}"
}

# 3. Hapus Akun
delete_user() {
    read -p "Username yang akan dihapus: " user
    userdel -f $user && echo -e "${RED}User $user dihapus.${NC}" || echo "User tidak ada."
}

# 4. Cek Akun Aktif
cek_user() {
    echo -e "${YELLOW}Daftar User Aktif:${NC}"
    printf "%-15s %-15s %-10s\n" "USER" "EXP" "STATUS"
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        uid=$(id -u "$user" 2>/dev/null)
        if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ]; then
            expire=$(date -d "1970-01-01 $exp days" +"%d-%m-%Y")
            echo -e "$user \t $expire \t ${GREEN}Active${NC}"
        fi
    done < /etc/shadow
}

# 5. Auto-Delete Expired
auto_xp() {
    now=$(date +%s)
    while IFS=: read -r user _ _ _ _ _ _ exp _; do
        if [ -n "$exp" ] && [ "$exp" != " " ]; then
            exp_sec=$((exp * 86400))
            if [ "$now" -ge "$exp_sec" ]; then
                userdel -f "$user"
            fi
        fi
    done < /etc/shadow
}

# Menu Utama
while true; do
    echo -e "\n${CYAN}      MANAGER ZIVPN UDP${NC}"
    echo -e "1. Tambah Domain"
    echo -e "2. Buat Akun Zivpn"
    echo -e "3. Hapus Akun"
    echo -e "4. Cek Akun Aktif"
    echo -e "5. Bersihkan Expired"
    echo -e "x. Exit"
    read -p "Pilih menu: " menu
    case $menu in
        1) add_domain ;;
        2) create_user ;;
        3) delete_user ;;
        4) cek_user ;;
        5) auto_xp; echo "Selesai dibersihkan." ;;
        x) exit ;;
    esac
done
