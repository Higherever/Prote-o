#!/usr/bin/env bash
set -uo pipefail

# ═══════════════════════════════════════════════
#              CORES
# ═══════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ═══════════════════════════════════════════════
#     FUNÇÃO: Garantir paru ou yay disponível
# ═══════════════════════════════════════════════
garantir_aur_helper() {
    if command -v paru &>/dev/null || command -v yay &>/dev/null; then
        return 0
    fi
    echo ""
    echo -e "${YELLOW}Os gerenciadores de pacotes paru e yay não estão instalados.${NC}"
    read -p "Deseja instalar o paru para continuar? (s/n): " resposta
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        echo "Instalando paru..."
        sudo pacman -S --noconfirm --needed base-devel git
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
        cd "$tmpdir/paru"
        makepkg -si --noconfirm
        cd - > /dev/null
        rm -rf "$tmpdir"
    else
        echo -e "${RED}Instalação cancelada. Não é possível continuar sem paru ou yay.${NC}"
        return 1
    fi
}

# Helper: instalar via paru ou yay
aur_install() {
    if command -v paru &>/dev/null; then
        paru -S --noconfirm --needed "$@"
    elif command -v yay &>/dev/null; then
        yay -S --noconfirm --needed "$@"
    fi
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Instalar ferramentas de segurança
# ═══════════════════════════════════════════════
instalar_seguranca() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PROTEÇÃO COMPLETA — CachyOS (Gaming Safe)  ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"

    echo ""
    echo -e "${YELLOW}[0/5]${NC} Atualizando sistema..."
    sudo pacman -Syu --noconfirm

    echo ""
    echo -e "${YELLOW}[1/5]${NC} Instalando Cloudflare WARP..."
    curl -sS https://pkg.cloudflareclient.com/pubkey.gpg | gpg --import 2>/dev/null || true
    if ! command -v warp-cli &>/dev/null; then
        garantir_aur_helper || return 1
        aur_install cloudflare-warp-bin
    fi
    sudo systemctl enable --now warp-svc
    sleep 2
    warp-cli registration new 2>/dev/null || true
    warp-cli mode warp 2>/dev/null || true
    warp-cli connect 2>/dev/null || true
    echo -e "${GREEN}✔ WARP configurado${NC}"

    echo ""
    echo -e "${YELLOW}[2/5]${NC} Hardening do kernel (compatível com jogos)..."
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
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
SYSCTL
    sudo sysctl --system > /dev/null 2>&1
    echo -e "${GREEN}✔ Kernel hardening aplicado (anti-cheat compatível)${NC}"

    echo ""
    echo -e "${YELLOW}[3/5]${NC} Configurando firewall nftables (gaming-safe)..."
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
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 drop
        tcp flags fin,syn / fin,syn drop
        tcp flags syn,rst / syn,rst drop
        tcp flags fin,rst / fin,rst drop
        tcp flags fin,psh,urg / fin,psh,urg drop
        tcp flags syn limit rate 50/second burst 100 packets accept
        tcp flags != syn ct state new drop
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        udp dport 68 accept
        udp dport 546 accept
        tcp dport { 27015-27050 } accept
        udp dport { 27000-27100, 4380 } accept
        tcp dport { 80, 443, 1119, 3074, 3724, 4000, 5040, 5222, 6113-6115 } accept
        udp dport { 3478-3479, 4379-4380, 5060, 5062, 6250, 12000-64000 } accept
        limit rate 5/minute log prefix "[nftables-DROP] " drop
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
    echo -e "${GREEN}✔ Firewall ativo (Steam + Blizzard liberados)${NC}"

    echo ""
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

    echo ""
    echo -e "${YELLOW}[5/5]${NC} Verificando tudo..."
    verificar_status
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Instalar ferramentas para jogos
# ═══════════════════════════════════════════════
instalar_jogos() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  INSTALAÇÃO DE FERRAMENTAS PARA JOGOS       ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"

    echo ""
    echo -e "${YELLOW}[1/3]${NC} Verificando AUR helper..."
    garantir_aur_helper || return 1

    echo ""
    echo -e "${YELLOW}[2/3]${NC} Instalando drivers e dependências..."
    sudo pacman -S --noconfirm --needed \
        amd-ucode \
        cachyos-gaming-applications \
        cachyos-gaming-meta \
        coolercontrol \
        gamemode \
        gamescope \
        lact \
        lib32-libva-mesa-driver \
        lib32-mesa \
        lib32-mesa-vdpau \
        lib32-vulkan-icd-loader \
        lib32-vulkan-radeon \
        libva-mesa-driver \
        linux-firmware \
        mangohud \
        mesa \
        mesa-vdpau \
        power-profiles-daemon \
        protontricks \
        umu-launcher \
        vulkan-icd-loader \
        vulkan-mesa-implicit-layers \
        vulkan-radeon \
        vulkan-tools \
        winetricks \
        xf86-video-amdgpu

    echo ""
    echo -e "${YELLOW}[3/3]${NC} Instalando aplicativos (AUR + repos)..."
    aur_install \
        steam \
        heroic-games-launcher-bin \
        lutris \
        protonup-qt \
        proton-cachyos-slr \
        wine-cachyos-opt \
        vesktop \
        google-chrome \
        lact \
        protontricks \
        mangohud \
        goverlay

    echo ""
    echo -e "${GREEN}✔ Instalação de ferramentas e dependências para jogos concluída.${NC}"
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Verificar status dos serviços
# ═══════════════════════════════════════════════
verificar_status() {
    echo ""
    echo -e "${CYAN}─── Cloudflare WARP ───${NC}"
    WARP_STATUS=$(warp-cli status 2>/dev/null | head -5 || echo "Não conectado")
    echo "$WARP_STATUS"

    echo ""
    echo -e "${CYAN}─── IP Público ───${NC}"
    NOVO_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "erro")
    echo -e "IP: ${GREEN}${NOVO_IP}${NC}"
    WARP_CHECK=$(curl -s --max-time 5 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "warp=" || echo "warp=off")
    if echo "$WARP_CHECK" | grep -q "warp=on"; then
        echo -e "${GREEN}✔ WARP ativo — IP real OCULTO${NC}"
    else
        echo -e "${RED}⚠ WARP não está ativo. Execute: warp-cli connect${NC}"
    fi

    echo ""
    echo -e "${CYAN}─── Firewall ───${NC}"
    if sudo nft list ruleset 2>/dev/null | grep -q "policy drop"; then
        echo -e "${GREEN}✔ Firewall ativo — política DROP${NC}"
    else
        echo -e "${RED}⚠ Firewall pode não estar configurado${NC}"
    fi

    echo ""
    echo -e "${CYAN}─── Fail2Ban ───${NC}"
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}✔ Fail2Ban ativo${NC}"
        sudo fail2ban-client status sshd 2>/dev/null || true
    else
        echo -e "${RED}⚠ Fail2Ban não está rodando${NC}"
    fi

    echo ""
    echo -e "${CYAN}─── Kernel (Gaming Safe) ───${NC}"
    SYNCOOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
    RPFILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)
    ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
    PTRACE=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)
    echo "SYN Cookies:     $([ "$SYNCOOKIES" = "1" ] && echo -e "${GREEN}✔ Ativo${NC}" || echo -e "${RED}✘ Inativo${NC}")"
    echo "RP Filter:       $([ "$RPFILTER" = "1" ] && echo -e "${GREEN}✔ Ativo${NC}" || echo -e "${RED}✘ Inativo${NC}")"
    echo "ASLR:            $([ "$ASLR" = "2" ] && echo -e "${GREEN}✔ Full${NC}" || echo -e "${RED}✘ Parcial${NC}")"
    echo "Ptrace (AC):     $([ "$PTRACE" = "1" ] && echo -e "${GREEN}✔ Compatível com anti-cheat${NC}" || echo -e "${RED}✘ Pode bloquear jogos!${NC}")"

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ PROTEÇÃO APLICADA (GAMING SAFE)            ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}•${NC} IP oculto via Cloudflare WARP"
    echo -e "  ${GREEN}•${NC} Firewall nftables (DROP + portas gaming)"
    echo -e "  ${GREEN}•${NC} Kernel hardening (anti-cheat compatível)"
    echo -e "  ${GREEN}•${NC} Fail2Ban anti brute-force"
    echo -e "  ${GREEN}•${NC} Steam / Battle.net / Overwatch 2 LIBERADOS"
    echo ""
    echo -e "  Verifique em: ${CYAN}https://whoer.net${NC}"
    echo -e "                ${CYAN}https://ipleak.net${NC}"
    echo ""
    echo -e "  Comandos úteis:"
    echo -e "    warp-cli status              — ver status do WARP"
    echo -e "    warp-cli disconnect          — desconectar (se jogo travar)"
    echo -e "    warp-cli connect             — reconectar WARP"
    echo -e "    sudo nft list ruleset        — ver regras do firewall"
    echo -e "    sudo fail2ban-client status  — ver bans ativos"
}

# ═══════════════════════════════════════════════
#              MENU PRINCIPAL
# ═══════════════════════════════════════════════
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}     INSTALADOR — CachyOS (Gaming Safe)      ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo ""
echo "Escolha uma opção:"
echo "  1) Instalar ferramentas de segurança"
echo "  2) Instalar ferramentas e dependências para jogos"
echo "  3) Configuração completa"
echo ""
read -p "Digite o número da opção desejada: " opcao

case $opcao in
    1)
        instalar_seguranca
        ;;
    2)
        instalar_jogos
        ;;
    3)
        instalar_seguranca
        instalar_jogos
        ;;
    *)
        echo -e "${RED}Opção inválida. Saindo...${NC}"
        exit 1
        ;;
esac