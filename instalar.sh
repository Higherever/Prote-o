#!/usr/bin/env bash
set -euo pipefail

# --- Sistema de logging (acumulativo persistente num diretório específico) ---
# O arquivo de log final será movido para logs/logBack após a execução.
TEMP_LOG="$(mktemp -t instalar_log.XXXXXX)" || { echo "Falha ao criar log temporário"; exit 1; }
# preserva stdout/stderr originais
exec 3>&1 4>&2
# redireciona stdout/stderr para console e para o log temporário
exec > >(tee -a "$TEMP_LOG") 2>&1

echo "========================================"
echo "Script: $0"
echo "Início: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Usuário: $(whoami)"
echo "PWD: $PWD"
echo "Args: $*"
echo "========================================"

set -o errtrace

on_error() {
    local exit_code=$?
    local lineno=${1:-0}
    local last_cmd=${BASH_COMMAND:-}
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: comando '${last_cmd}' retornou ${exit_code} na linha ${lineno}" >&2
}

on_exit() {
    local exit_code=$?
    # restaura fds antes de mover/mostrar mensagem final
    exec 1>&3 2>&4
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local dest_dir="$script_dir/logs/logBack"
    mkdir -p "$dest_dir"
    local dest_file="$dest_dir/instalar_$(date '+%Y%m%d_%H%M%S').log"
    mv "$TEMP_LOG" "$dest_file"
    chmod 644 "$dest_file" 2>/dev/null || true
    if [ "$exit_code" -ne 0 ]; then
        echo "Log de ERRO salvo cumulativamente em: $dest_file" >&2
    else
        echo "Log de SUCESSO salvo cumulativamente em: $dest_file"
    fi
}

trap 'on_error $LINENO' ERR
trap 'on_exit' EXIT

# ═══════════════════════════════════════════════
#              CORES
# ═══════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[AVISO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $*" >&2
}

# Helper para leitura interativa (restaura temporariamente os descritores originais)
interactive_read() {
    local prompt="$1"
    local -n var_ref=$2
    # Restaura temporariamente stdout/stderr originais para leitura interativa
    exec >&3 2>&4
    read -p "$prompt" var_ref
    # Restaura redirecionamento para tee
    exec > >(tee -a "$TEMP_LOG") 2>&1
}

# Execução segura com captura de saída para análise de erros
CMD_OUTPUT=""
CMD_RC=0

# run_cmd: executa um comando (array) com captura de saída
# parâmetros: descrição (string) + comando e argumentos
run_cmd() {
    local desc="$1"
    shift
    local -a cmd=("$@")
    log_info "Executando: ${desc} -> ${cmd[*]}"
    if [ "${DRY_RUN}" = true ]; then
        CMD_OUTPUT="DRY-RUN: ${cmd[*]}"
        CMD_RC=0
        return 0
    fi
    set +e
    local out
    out=$("${cmd[@]}" 2>&1)
    local rc=$?
    set -e
    CMD_OUTPUT="$out"
    CMD_RC=$rc
    printf '%s
' "$out"
    printf '[%s] CMD: %s RC:%d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${cmd[*]}" "$rc" >> "$TEMP_LOG"
    if [ $rc -ne 0 ]; then
        printf '[%s] ERRO: %s\nSaída:\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$desc" "$out" >> "$TEMP_LOG"
    fi
    return $rc
}

# Lista simples de conflitos conhecidos (remover antes de instalar a versão oficial)
resolve_known_conflicts() {
    local -a known=(lib32-mesa-git)
    for pkg in "${known[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_warn "Pacote conflitante detectado instalado: $pkg — removendo automaticamente para evitar conflito."
            if [ "${DRY_RUN}" = true ]; then
                log_info "DRY-RUN: sudo pacman -R --noconfirm $pkg"
            else
                run_cmd "remover $pkg" sudo pacman -R --noconfirm "$pkg"
                if [ $CMD_RC -ne 0 ]; then
                    log_error "Falha ao remover $pkg (rc=$CMD_RC). Ver arquivo de log para detalhes." 
                else
                    log_info "Remoção de $pkg concluída." 
                fi
            fi
        fi
    done
}

# Modo de execução: dry-run
DRY_RUN=false
for __arg in "$@"; do
    case "${__arg}" in
        --dry-run|-n)
            DRY_RUN=true
            shift || true
            ;;
    esac
done
if [ "${DRY_RUN}" = true ]; then
    log_warn "Modo DRY-RUN ativo: nenhuma alteração será aplicada ao sistema."
fi

# Helpers para dry-run / execução segura
write_file() {
    local path="$1"
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: conteúdo que seria escrito em ${path}:"
        cat -
        return 0
    else
        sudo tee "${path}" > /dev/null
    fi
}

run_pacman() {
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: pacman $*"
        return 0
    fi

    # Antes: resolver conflitos conhecidos proativamente
    resolve_known_conflicts

    run_cmd "pacman $*" sudo pacman "$@"
    if [ $CMD_RC -ne 0 ]; then
        # Mensagens não-fatais (pacote já instalado / nada para fazer)
        if echo "$CMD_OUTPUT" | grep -qiE "está atualizado|is up to date|nada para fazer|already up-to-date|nothing to do"; then
            log_info "pacman informou que nada precisa ser feito (pacote já instalado/up-to-date). Ignorando erro." 
            return 0
        fi

        # Conflitos de pacotes — tentar resolver automaticamente e reexecutar
        if echo "$CMD_OUTPUT" | grep -qi "conflito de pacotes"; then
            log_warn "Conflito de pacotes detectado. Tentando resolver conflitos conhecidos e reinstalar."
            resolve_known_conflicts
            run_cmd "pacman retry $*" sudo pacman "$@"
            if [ $CMD_RC -ne 0 ]; then
                log_error "Instalação via pacman falhou após tentativa de resolver conflitos. Saída: $CMD_OUTPUT"
                return $CMD_RC
            fi
            return 0
        fi

        # Falha de download (404) — atualizar base e tentar novamente
        if echo "$CMD_OUTPUT" | grep -qiE "falha ao obter o arquivo|The requested URL returned error|404"; then
            log_warn "Falha de download detectada (possível mirror quebrado). Forçando refresh dos repositórios e tentando novamente."
            run_cmd "pacman -Syy" sudo pacman -Syy --noconfirm
            run_cmd "pacman retry $*" sudo pacman "$@"
            if [ $CMD_RC -ne 0 ]; then
                log_error "Instalação via pacman falhou após refresh (provável problema externo). Saída: $CMD_OUTPUT"
                return $CMD_RC
            fi
            return 0
        fi

        # Caso geral — registra e propaga o erro
        log_error "pacman retornou erro (rc=$CMD_RC). Saída registrada no log temporário." 
        return $CMD_RC
    fi
    return 0
}

run_nft() {
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: nft $*"
        return 0
    else
        sudo nft "$@"
    fi
}

run_systemctl() {
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: systemctl $*"
        return 0
    else
        sudo systemctl "$@"
    fi
}

backup_file() {
    local source_path=$1
    local backup_root=$2
    local backup_name=$3

    if sudo test -f "$source_path"; then
        sudo cp -a "$source_path" "$backup_root/$backup_name"
    else
        : > "$backup_root/$backup_name.absent"
    fi
}

restore_file() {
    local target_path=$1
    local backup_root=$2
    local backup_name=$3

    if [[ -f "$backup_root/$backup_name" ]]; then
        sudo cp -a "$backup_root/$backup_name" "$target_path"
    elif [[ -f "$backup_root/$backup_name.absent" ]]; then
        sudo rm -f "$target_path"
    fi
}

save_service_state() {
    local service_name=$1
    local backup_root=$2
    local enabled_state="no"
    local active_state="no"

    if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
        enabled_state="yes"
    fi
    if systemctl is-active --quiet "$service_name"; then
        active_state="yes"
    fi

    printf '%s\n%s\n' "$enabled_state" "$active_state" > "$backup_root/$service_name.state"
}

restore_service_state() {
    local service_name=$1
    local backup_root=$2
    local state_file="$backup_root/$service_name.state"
    local enabled_state
    local active_state
    local -a service_state

    if [[ ! -f "$state_file" ]]; then
        return 0
    fi

    mapfile -t service_state < "$state_file"
    enabled_state=${service_state[0]:-no}
    active_state=${service_state[1]:-no}

    if [[ "$enabled_state" == "yes" ]]; then
        run_systemctl enable "$service_name" >/dev/null 2>&1 || true
    else
        run_systemctl disable "$service_name" >/dev/null 2>&1 || true
    fi

    if [[ "$active_state" == "yes" ]]; then
        run_systemctl start "$service_name" >/dev/null 2>&1 || true
    else
        run_systemctl stop "$service_name" >/dev/null 2>&1 || true
    fi
}

backup_security_state() {
    local backup_root=$1

    backup_file "/etc/sysctl.d/99-hardening.conf" "$backup_root" "99-hardening.conf"
    backup_file "/etc/nftables.conf" "$backup_root" "nftables.conf"
    backup_file "/etc/fail2ban/jail.local" "$backup_root" "jail.local"
    save_service_state "warp-svc" "$backup_root"
    save_service_state "nftables" "$backup_root"
    save_service_state "fail2ban" "$backup_root"
}

restore_security_state() {
    local backup_root=$1

    log_warn "Restaurando arquivos e serviços de segurança para o estado anterior."
    restore_file "/etc/sysctl.d/99-hardening.conf" "$backup_root" "99-hardening.conf"
    restore_file "/etc/nftables.conf" "$backup_root" "nftables.conf"
    restore_file "/etc/fail2ban/jail.local" "$backup_root" "jail.local"

    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: sysctl --system (simulação de restauração)."
    else
        sudo sysctl --system >/dev/null 2>&1 || true
    fi
    if sudo test -f /etc/nftables.conf; then
        run_nft -f /etc/nftables.conf >/dev/null 2>&1 || true
    fi

    restore_service_state "warp-svc" "$backup_root"
    restore_service_state "nftables" "$backup_root"
    restore_service_state "fail2ban" "$backup_root"
}

verificar_requisitos_completos() {
    local command_name

    for command_name in sudo pacman systemctl curl git grep; do
        if ! command -v "$command_name" &>/dev/null; then
            log_error "Dependência obrigatória ausente: $command_name"
            return 1
        fi
    done

    garantir_aur_helper || return 1
}

configuracao_completa() {
    local backup_root
    backup_root=$(mktemp -d)

    log_info "Validando pré-requisitos antes da configuração completa."
    if ! verificar_requisitos_completos; then
        rm -rf "$backup_root"
        return 1
    fi

    backup_security_state "$backup_root"

    if ! instalar_seguranca; then
        restore_security_state "$backup_root"
        rm -rf "$backup_root"
        return 1
    fi

    if ! instalar_jogos; then
        log_error "A etapa de jogos falhou após aplicar a etapa de segurança."
        restore_security_state "$backup_root"
        rm -rf "$backup_root"
        return 1
    fi

    rm -rf "$backup_root"
    log_success "Configuração completa finalizada sem falhas."
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Garantir paru ou yay disponível
# ═══════════════════════════════════════════════
garantir_aur_helper() {
    if command -v paru &>/dev/null || command -v yay &>/dev/null; then
        return 0
    fi
    echo ""
    log_warn "Os gerenciadores de pacotes paru e yay não estão instalados."
    interactive_read "Deseja instalar o paru para continuar? (s/n): " resposta
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        log_info "Instalando paru pelo AUR."
        if [ "${DRY_RUN}" = true ]; then
            log_info "DRY-RUN: pular instalação do paru (simulação)."
            return 0
        fi
        run_pacman -S --noconfirm --needed base-devel git
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
        if [[ ${EUID} -eq 0 ]]; then
            if [[ -z ${SUDO_USER:-} ]]; then
                log_error "Execute o script como usuário normal. makepkg não deve rodar como root."
                rm -rf "$tmpdir"
                return 1
            fi
            sudo -u "$SUDO_USER" bash -lc "cd '$tmpdir/paru' && makepkg -si --noconfirm"
        else
            (
                cd "$tmpdir/paru"
                makepkg -si --noconfirm
            )
        fi
        rm -rf "$tmpdir"
        log_success "paru instalado com sucesso."
    else
        log_error "Instalação cancelada. Não é possível continuar sem paru ou yay."
        return 1
    fi
}

# Helper: instalar via paru ou yay
aur_install() {
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: aur_install (simulação): $*"
        return 0
    fi
    if command -v paru &>/dev/null; then
        run_cmd "paru -S --noconfirm --needed $*" paru -S --noconfirm --needed "$@"
        if [ $CMD_RC -ne 0 ]; then
            log_error "Erro ao instalar via paru: $* (rc=$CMD_RC). Ver log temporário para detalhes."
            return $CMD_RC
        fi
    elif command -v yay &>/dev/null; then
        run_cmd "yay -S --noconfirm --needed $*" yay -S --noconfirm --needed "$@"
        if [ $CMD_RC -ne 0 ]; then
            log_error "Erro ao instalar via yay: $* (rc=$CMD_RC). Ver log temporário para detalhes."
            return $CMD_RC
        fi
    else
        log_error "Nenhum helper AUR disponível para instalar: $*"
        return 1
    fi
}

# Instala Cloudflare WARP e aceita automaticamente os termos quando possível
install_cloudflare_warp() {
    log_info "Instalando Cloudflare WARP (aceitação automática de termos quando suportado)."
    garantir_aur_helper || return 1
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: instalar cloudflare-warp-bin (simulação)."
        return 0
    fi

    if command -v paru &>/dev/null; then
        set +e
        paru -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$TEMP_LOG"
        local rc=${PIPESTATUS[0]:-1}
        set -e
    elif command -v yay &>/dev/null; then
        set +e
        yay -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$TEMP_LOG"
        local rc=${PIPESTATUS[0]:-1}
        set -e
    else
        aur_install cloudflare-warp-bin || return 1
        rc=0
    fi

    if [ "${rc:-0}" -ne 0 ]; then
        log_error "Instalação do cloudflare-warp-bin falhou (rc=${rc}). Ver log para detalhes."
        return ${rc}
    fi

    run_systemctl enable --now warp-svc || log_warn "Não foi possível habilitar warp-svc (verifique permissões)."

    # Registrar e conectar — tentar modo não interativo quando possível
    if command -v warp-cli &>/dev/null; then
        set +e
        warp-cli registration new --accept-tos 2>&1 | tee -a "$TEMP_LOG" || true
        warp-cli mode warp 2>&1 | tee -a "$TEMP_LOG" || true
        warp-cli connect --accept-tos 2>&1 | tee -a "$TEMP_LOG" || true
        set -e
    fi

    return 0
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Instalar ferramentas de segurança
# ═══════════════════════════════════════════════
instalar_seguranca() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PROTEÇÃO COMPLETA — CachyOS (Jogo Seguro)  ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"

    echo ""
    echo -e "${YELLOW}[0/5]${NC} Atualizando sistema..."
    log_info "Executando atualização completa do sistema via pacman."
    run_pacman -Syu --noconfirm

    echo ""
    echo -e "${YELLOW}[1/5]${NC} Instalando Cloudflare WARP..."
    log_info "Verificando presença do warp-cli e do serviço warp-svc."
    if ! command -v warp-cli &>/dev/null; then
        install_cloudflare_warp || {
            log_error "Falha ao instalar Cloudflare WARP. Verifique o log para detalhes." 
        }
    fi

    if ! command -v warp-cli &>/dev/null; then
        if [ "${DRY_RUN}" = true ]; then
            log_info "DRY-RUN: warp-cli não está instalado, simulando instalação em dry-run."
        else
            log_error "warp-cli não foi instalado corretamente."
            return 1
        fi
    fi

    run_systemctl enable --now warp-svc || log_warn "Não foi possível habilitar warp-svc automaticamente."
    if ! systemctl is-active --quiet warp-svc; then
        if [ "${DRY_RUN}" = true ]; then
            log_info "DRY-RUN: serviço warp-svc não iniciado (simulação)."
        else
            log_error "O serviço warp-svc não iniciou corretamente. Ver log para detalhes."
            return 1
        fi
    fi
    sleep 2
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: pular comandos 'warp-cli registration/mode/connect' (simulação)."
    else
        if ! warp-cli status 2>/dev/null | grep -qi "registration\|registered\|connected"; then
            log_info "Registrando o cliente WARP neste sistema (não-interativo quando possível)."
            set +e
            warp-cli registration new --accept-tos 2>&1 | tee -a "$TEMP_LOG" || true
            set -e
        fi
        log_info "Aplicando modo WARP e iniciando conexão."
        warp-cli mode warp 2>&1 | tee -a "$TEMP_LOG" || true
        warp-cli connect --accept-tos 2>&1 | tee -a "$TEMP_LOG" || true
        sleep 2
        if warp-cli status 2>/dev/null | grep -qi "connected"; then
            log_success "WARP configurado e conectado."
        else
            log_error "WARP não confirmou conexão após a configuração. Saída registrada no log." 
            return 1
        fi
    fi

    echo ""
    echo -e "${YELLOW}[2/5]${NC} Hardening do kernel (compatível com jogos)..."
    log_info "Gravando parâmetros sysctl de hardening em /etc/sysctl.d/99-hardening.conf."
    write_file /etc/sysctl.d/99-hardening.conf > /dev/null << 'SYSCTL'
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
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: sysctl --system (simulação)."
    else
        sudo sysctl --system > /dev/null 2>&1
    fi
    log_success "Kernel hardening aplicado com perfil compatível com jogos."

    echo ""
    echo -e "${YELLOW}[3/5]${NC} Configurando firewall nftables (gaming-safe)..."
    log_info "Instalando nftables e escrevendo a política de firewall."
    run_pacman -S --noconfirm --needed nftables
    write_file /etc/nftables.conf > /dev/null << 'NFTABLES'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        tcp flags & (fin|syn) == (fin|syn) drop
        tcp flags & (syn|rst) == (syn|rst) drop
        tcp flags & (fin|rst) == (fin|rst) drop
        tcp flags & (fin|psh|urg) == (fin|psh|urg) drop
        tcp flags syn limit rate 50/second burst 100 packets accept
        ct state new tcp flags & (fin|syn|rst|ack) != syn drop
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
    if ! run_nft -c -f /etc/nftables.conf; then
        log_error "A validação do arquivo /etc/nftables.conf falhou."
        return 1
    fi
    run_systemctl enable --now nftables
    run_nft -f /etc/nftables.conf
    log_success "Firewall ativo com regras para jogos aplicadas."

    echo ""
    echo -e "${YELLOW}[4/5]${NC} Instalando Fail2Ban..."
    log_info "Instalando Fail2Ban e gravando jail.local."
    run_pacman -S --noconfirm --needed fail2ban
    write_file /etc/fail2ban/jail.local > /dev/null << 'FAIL2BAN'
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
    run_systemctl enable --now fail2ban
    log_success "Fail2Ban ativo."

    echo ""
    echo -e "${YELLOW}[5/5]${NC} Verificando tudo..."
    log_info "Executando verificações finais de status."
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
    log_info "Instalando pacotes de drivers, Vulkan, Wine e utilitários de jogos."
    run_pacman -S --noconfirm --needed \
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
    log_info "Instalando launchers e ferramentas complementares via helper AUR."
    aur_install \
        steam \
        heroic-games-launcher-bin \
        lutris \
        protonup-qt \
        proton-cachyos-slr \
        wine-cachyos-opt \
        vesktop \
        google-chrome \
        goverlay

    echo ""
    log_success "Instalação de ferramentas e dependências para jogos concluída."
}

# ═══════════════════════════════════════════════
#     FUNÇÃO: Verificar status dos serviços
# ═══════════════════════════════════════════════
verificar_status() {
    echo ""
    echo -e "${CYAN}─── Cloudflare WARP ───${NC}"
    if command -v warp-cli &>/dev/null; then
        WARP_STATUS=$(warp-cli status 2>/dev/null | head -5 || echo "Não conectado")
    else
        WARP_STATUS="warp-cli não está instalado"
    fi
    echo "$WARP_STATUS"

    echo ""
    echo -e "${CYAN}─── IP Público ───${NC}"
    NOVO_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "erro")
    echo -e "IP: ${GREEN}${NOVO_IP}${NC}"
    WARP_CHECK=$(curl -s --max-time 5 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "warp=" || echo "warp=off")
    if echo "$WARP_CHECK" | grep -q "warp=on"; then
        log_success "WARP ativo e IP real oculto."
    else
        log_warn "WARP não está ativo. Execute: warp-cli connect"
    fi

    echo ""
    echo -e "${CYAN}─── Firewall ───${NC}"
    run_cmd "listar nft ruleset" sudo nft list table inet filter
    if [ $CMD_RC -ne 0 ]; then
        log_error "Não foi possível listar regras nftables (rc=$CMD_RC). Saída: $CMD_OUTPUT"
        log_warn "Verifique se o serviço 'nftables' está ativo: sudo systemctl status nftables"
    else
        if echo "$CMD_OUTPUT" | grep -q "type filter hook input priority 0; policy drop;" \
           && echo "$CMD_OUTPUT" | grep -q "type filter hook forward priority 0; policy drop;"; then
            log_success "Firewall ativo com política DROP em input e forward."
        else
            log_warn "Firewall parece não aplicar a política DROP esperada. Conteúdo do ruleset:\n$CMD_OUTPUT"
        fi
    fi

    echo ""
    echo -e "${CYAN}─── Fail2Ban ───${NC}"
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2Ban ativo."
        sudo fail2ban-client status sshd 2>/dev/null || true
    else
        log_warn "Fail2Ban não está rodando."
    fi

    echo ""
    echo -e "${CYAN}─── Kernel (Jogo Seguro) ───${NC}"
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
    echo -e "${GREEN}  ✅ PROTEÇÃO APLICADA (Jogo Seguro)            ${NC}"
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
# Se a variável PROTECAO_RUN_FUNC estiver definida, executa a função
# diretamente (útil para chamadas automatizadas / GUI). Isso evita que o
# menu interativo seja apresentado quando o script for chamado por outra
# aplicação via source/exec.
if [ -n "${PROTECAO_RUN_FUNC:-}" ]; then
    func="$PROTECAO_RUN_FUNC"
    # Verifica se a função existe antes de executar
    if declare -F "$func" >/dev/null 2>&1; then
        log_info "Executando função via PROTECAO_RUN_FUNC: $func"
        # Chama a função e sai com seu código de retorno
        "$func"
        exit $?
    else
        log_error "Função solicitada não encontrada: $func"
        exit 2
    fi
fi

echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}     INSTALADOR — CachyOS (Jogo seguro)      ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo ""
echo "Escolha uma opção:"
echo "  1) Instalar ferramentas de segurança"
echo "  2) Instalar ferramentas e dependências para jogos"
echo "  3) Configuração completa"
echo ""
interactive_read "Digite o número da opção desejada: " opcao

case $opcao in
    1)
        instalar_seguranca
        ;;
    2)
        instalar_jogos
        ;;
    3)
        configuracao_completa
        ;;
    *)
        log_error "Opção inválida. Saindo..."
        exit 1
        ;;
esac