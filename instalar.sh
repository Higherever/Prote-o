#!/usr/bin/env bash
set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN}  PROTEÇÃO COMPLETA — CachyOS         ${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"

echo -e "${YELLOW}[0/5]${NC} Atualizando sistema..."
sudo pacman -Syu --noconfirm
echo -e "${YELLOW}[1/5]${NC} Instalando Cloudflare WARP..."
curl -sS https://pkg.cloudflareclient.com/pubkey.gpg | gpg --import 2>/dev/null || true
if ! command -v warp-cli &>/dev/null; then
    paru -S --noconfirm cloudflare-warp-bin
fi
sudo systemctl enable --now warp-svc
sleep 2
warp-cli registration new 2>/dev/null || true
warp-cli mode warp 2>/dev/null || true
warp-cli connect 2>/dev/null || true
echo -e "${GREEN}✔ WARP configurado${NC}"
echo -e "${YELLOW}[2/5]${NC} Hardening do kernel..."
sudo tee /etc/sysctl.d/99-hardening.conf > /dev/null << 'SYSCTL'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.dmesg_restrict = 1
SYSCTL
sudo sysctl --system > /dev/null 2>&1
echo -e "${GREEN}✔ Kernel hardening aplicado${NC}"
echo -e "${YELLOW}[3/5]${NC} Configurando firewall nftables..."
sudo pacman -S --noconfirm --needed nftables
sudo tee /etc/nftables.conf > /dev/null << 'NFTABLES'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        tcp flags syn limit rate 25/second burst 50 packets accept
        tcp flags != syn ct state new drop
        tcp flags fin,psh,urg / fin,psh,urg drop
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 drop
        tcp flags fin,syn / fin,syn drop
        tcp flags syn,rst / syn,rst drop
        tcp flags fin,rst / fin,rst drop
        ip protocol icmp icmp type echo-request limit rate 1/second burst 2 packets accept
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 1/second burst 2 packets accept
        ip6 nexthdr icmpv6 icmpv6 type { nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept
        udp dport 68 accept
        udp dport 546 accept
        tcp dport { 80, 443, 1119, 3724, 4000, 5040, 6113-6115 } accept
        udp dport { 3478-3479, 5060, 5062, 6250, 12000-64000 } accept
        limit rate 5/minute log prefix "[nftables-BLOCKED] " drop
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
NFTABLES
sudo systemctl enable --now nftables
sudo nft -f /etc/nftables.conf
echo -e "${GREEN}✔ Firewall nftables ativo (com portas Blizzard)${NC}"
echo -e "${YELLOW}[4/5]${NC} Instalando Fail2Ban..."
sudo pacman -S --noconfirm --needed fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null << 'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = nftables-multiport
banaction_allports = nftables-allports
[sshd]
enabled = true
port = ssh
backend = systemd
maxretry = 3
bantime = 3600
FAIL2BAN
sudo systemctl enable --now fail2ban
echo -e "${GREEN}✔ Fail2Ban ativo${NC}"
echo -e "${YELLOW}[5/5]${NC} Verificando..."
echo ""
NOVO_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "erro")
WARP_CHECK=$(curl -s --max-time 5 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "warp=" || echo "warp=off")
NFT_CHECK=$(sudo nft list ruleset 2>/dev/null | grep -c "policy drop" || echo "0")
F2B_CHECK=$(systemctl is-active fail2ban 2>/dev/null || echo "inactive")
SYNCOOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "0")
echo -e "${CYAN}IP Público:${NC}  $NOVO_IP"
if echo "$WARP_CHECK" | grep -q "warp=on"; then
    echo -e "${CYAN}WARP:${NC}        ${GREEN}✔ Ativo — IP oculto${NC}"
else
    echo -e "${CYAN}WARP:${NC}        ${RED}✘ Inativo — execute: warp-cli connect${NC}"
fi
if [ "$NFT_CHECK" -ge 1 ] 2>/dev/null; then
    echo -e "${CYAN}Firewall:${NC}    ${GREEN}✔ Ativo (DROP)${NC}"
else
    echo -e "${CYAN}Firewall:${NC}    ${RED}✘ Verificar${NC}"
fi
if [ "$F2B_CHECK" = "active" ]; then
    echo -e "${CYAN}Fail2Ban:${NC}    ${GREEN}✔ Ativo${NC}"
else
    echo -e "${CYAN}Fail2Ban:${NC}    ${RED}✘ Inativo${NC}"
fi
if [ "$SYNCOOKIES" = "1" ]; then
    echo -e "${CYAN}Kernel:${NC}      ${GREEN}✔ Hardening ativo${NC}"
else
    echo -e "${CYAN}Kernel:${NC}      ${RED}✘ Verificar${NC}"
fi
echo ""
echo -e "${GREEN}✅ Proteção completa aplicada!${NC}"
echo -e "Verifique: https://whoer.net | https://ipleak.net"