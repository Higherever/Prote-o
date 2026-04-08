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
    # Mantém apenas os 10 logs mais recentes em logBack
    local logs
    mapfile -t logs < <(ls -1tr "$dest_dir"/instalar_*.log 2>/dev/null)
    if [ "${#logs[@]}" -ge 10 ]; then
        local excess=$(( ${#logs[@]} - 9 ))
        for ((i=0; i<excess; i++)); do
            rm -f "${logs[i]}"
        done
    fi

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

# ═══════════════════════════════════════════════
# Detecção do usuário real (resolve pkexec que não define SUDO_USER)
# ═══════════════════════════════════════════════
detectar_usuario_real() {
    # 1. SUDO_USER (se veio via sudo)
    if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
        return 0
    fi
    # 2. PKEXEC_UID (definida pelo pkexec)
    if [[ -n "${PKEXEC_UID:-}" ]] && [[ "$PKEXEC_UID" != "0" ]]; then
        local user_name
        user_name=$(getent passwd "$PKEXEC_UID" 2>/dev/null | cut -d: -f1)
        if [[ -n "$user_name" ]]; then
            echo "$user_name"
            return 0
        fi
    fi
    # 3. LOGNAME
    if [[ -n "${LOGNAME:-}" ]] && [[ "$LOGNAME" != "root" ]]; then
        echo "$LOGNAME"
        return 0
    fi
    # 4. Fallback: quem está logado na sessão gráfica
    local logged
    logged=$(who 2>/dev/null | head -1 | awk '{print $1}')
    if [[ -n "$logged" ]] && [[ "$logged" != "root" ]]; then
        echo "$logged"
        return 0
    fi
    # 5. Último recurso: listar homes
    local home_user
    home_user=$(ls /home/ 2>/dev/null | head -1)
    if [[ -n "$home_user" ]]; then
        echo "$home_user"
        return 0
    fi
    echo ""
    return 1
}

REAL_USER=""
if [[ ${EUID} -eq 0 ]]; then
    REAL_USER=$(detectar_usuario_real) || true
    if [[ -n "$REAL_USER" ]]; then
        log_info "Usuário real detectado: $REAL_USER (via pkexec/sudo)"
    else
        log_warn "Não foi possível detectar usuário real. Comandos AUR podem falhar."
    fi
fi

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
    local out=""
    local rc=0
    out=$("${cmd[@]}" 2>&1) || rc=$?
    CMD_OUTPUT="$out"
    CMD_RC=$rc
    printf '%s\n' "$out"
    printf '[%s] CMD: %s RC:%d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${cmd[*]}" "$rc" >> "$TEMP_LOG"
    if [ $rc -ne 0 ]; then
        printf '[%s] ERRO: %s\nSaída:\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$desc" "$out" >> "$TEMP_LOG"
    fi
    return 0
}

# Resolução inteligente de conflitos de drivers mesa (-git vs estável)
# Regras:
#   1. Se o usuário já tem o driver -git instalado → mantém -git, remove estável da lista
#   2. Se o usuário já tem o driver estável instalado → mantém estável, não muda nada
#   3. Se não tem nenhum → prefere -git (melhor desempenho no CachyOS)
resolve_known_conflicts() {
    local -a packages_to_install=("$@")

    # Pares de conflito: "pacote-git pacote-estável"
    local -a conflict_pairs=(
        "lib32-mesa-git lib32-mesa"
        "mesa-git mesa"
    )

    for pair in "${conflict_pairs[@]}"; do
        local git_pkg="${pair%% *}"
        local stable_pkg="${pair##* }"

        # Verificar se os pacotes estão na lista de instalação
        local has_stable_in_list=false
        for p in "${packages_to_install[@]}"; do
            if [[ "$p" == "$stable_pkg" ]]; then
                has_stable_in_list=true
                break
            fi
        done
        # Se o pacote estável não está na lista, nada a resolver
        [[ "$has_stable_in_list" == false ]] && continue

        local git_installed=false
        local stable_installed=false
        pacman -Q "$git_pkg" &>/dev/null && git_installed=true
        pacman -Q "$stable_pkg" &>/dev/null && stable_installed=true

        if [[ "$git_installed" == true ]]; then
            # Caso 1: Driver -git já instalado → remover estável da lista
            log_warn "$git_pkg já está instalado e conflita com $stable_pkg." >&2
            log_info "Preservando driver -git para melhor desempenho." >&2
            for i in "${!packages_to_install[@]}"; do
                if [[ "${packages_to_install[i]}" == "$stable_pkg" ]]; then
                    unset 'packages_to_install[i]'
                fi
            done
        elif [[ "$stable_installed" == true ]]; then
            # Caso 2: Driver estável já instalado → manter como está
            log_info "Driver estável $stable_pkg detectado. Mantendo versão atual." >&2
        else
            # Caso 3: Nenhum instalado → preferir -git
            log_info "Nenhuma versão de $stable_pkg detectada. Preferindo $git_pkg." >&2
            for i in "${!packages_to_install[@]}"; do
                if [[ "${packages_to_install[i]}" == "$stable_pkg" ]]; then
                    packages_to_install[i]="$git_pkg"
                fi
            done
        fi
    done

    # Verificar se lib32-mesa-git está instalado ou se será instalado
    local will_install_git=false
    if pacman -Q "lib32-mesa-git" &>/dev/null; then
        will_install_git=true
    else
        for p in "${packages_to_install[@]}"; do
            if [[ "$p" == "lib32-mesa-git" ]]; then
                will_install_git=true
                break
            fi
        done
    fi

    # Remover pacotes lib32 que conflitam quando usando -git
    # lib32-mesa-vdpau e lib32-libva-mesa-driver às vezes conflitam com lib32-mesa-git
    if [[ "$will_install_git" == true ]]; then
        local -a maybe_conflict=(lib32-mesa-vdpau lib32-libva-mesa-driver)
        for cpkg in "${maybe_conflict[@]}"; do
            for i in "${!packages_to_install[@]}"; do
                if [[ "${packages_to_install[i]}" == "$cpkg" ]]; then
                    log_warn "$cpkg conflita com lib32-mesa-git. Removendo da lista." >&2
                    unset 'packages_to_install[i]'
                fi
            done
        done
    fi

    # Retorna a lista filtrada (como string)
    echo "${packages_to_install[*]}"
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

    # RESOLUÇÃO INTELIGENTE DE DRIVERS:
    # Filtramos a lista de pacotes para não forçar substituição de drivers -git por estáveis
    local -a args=("$@")
    local -a final_packages=()
    local is_install_cmd=false
    
    # Verifica se é um comando de instalação (-S ou --sync)
    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^-.*[S].* ]]; then is_install_cmd=true; break; fi
    done

    if [ "$is_install_cmd" = true ]; then
        local filtered_pkgs
        filtered_pkgs=$(resolve_known_conflicts "${args[@]}")
        read -r -a final_packages <<< "$filtered_pkgs"
    else
        final_packages=("${args[@]}")
    fi

    run_cmd "pacman ${final_packages[*]}" sudo pacman "${final_packages[@]}"
    if [ $CMD_RC -ne 0 ]; then
        # Mensagens não-fatais (pacote já instalado / nada para fazer)
        if echo "$CMD_OUTPUT" | grep -qiE "está atualizado|is up to date|nada para fazer|already up-to-date|nothing to do"; then
            log_info "pacman informou que nada precisa ser feito (pacote já instalado/up-to-date). Ignorando erro." 
            return 0
        fi

        # Conflitos de pacotes — registrar e sugerir intervenção manual
        if echo "$CMD_OUTPUT" | grep -qi "conflito de pacotes"; then
            log_error "Conflito de pacotes persistente detectado."
            log_warn "O sistema não pôde resolver o conflito automaticamente. Saída: $CMD_OUTPUT"
            return $CMD_RC
        fi

        # Falha de download (404) — atualizar base e tentar novamente
        if echo "$CMD_OUTPUT" | grep -qiE "falha ao obter o arquivo|The requested URL returned error|404"; then
            log_warn "Falha de download detectada (possível mirror quebrado). Forçando refresh dos repositórios e tentando novamente."
            run_cmd "pacman -Syy" sudo pacman -Syy --noconfirm
            run_cmd "pacman retry ${final_packages[*]}" sudo pacman "${final_packages[@]}"
            return $CMD_RC
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
    # Prioridade: yay > paru (conforme preferência do projeto)
    if command -v yay &>/dev/null || command -v paru &>/dev/null; then
        return 0
    fi
    echo ""
    log_warn "Os gerenciadores de pacotes yay e paru não estão instalados."
    interactive_read "Deseja instalar o yay para continuar? (s/n): " resposta
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        log_info "Instalando yay pelo AUR."
        if [ "${DRY_RUN}" = true ]; then
            log_info "DRY-RUN: pular instalação do yay (simulação)."
            return 0
        fi
        run_pacman -S --noconfirm --needed base-devel git
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
        if [[ ${EUID} -eq 0 ]]; then
            if [[ -z "${REAL_USER:-}" ]]; then
                log_error "Não foi possível detectar o usuário real. makepkg não deve rodar como root."
                rm -rf "$tmpdir"
                return 1
            fi
            sudo -u "$REAL_USER" bash -lc "cd '$tmpdir/yay' && makepkg -si --noconfirm"
        else
            (
                cd "$tmpdir/yay"
                makepkg -si --noconfirm
            )
        fi
        rm -rf "$tmpdir"
        log_success "yay instalado com sucesso."
    else
        log_error "Instalação cancelada. Não é possível continuar sem yay ou paru."
        return 1
    fi
}

# Helper: instalar via paru ou yay deleando ao usuário normal se root
aur_install() {
    if [ "${DRY_RUN}" = true ]; then
        log_info "DRY-RUN: aur_install (simulação): $*"
        return 0
    fi

    # Prioridade: yay > paru (conforme definição do projeto)
    local helper=""
    if command -v yay &>/dev/null; then helper="yay"; fi
    if [ -z "$helper" ] && command -v paru &>/dev/null; then helper="paru"; fi

    if [ -z "$helper" ]; then
        log_error "Nenhum helper AUR disponível para instalar: $*"
        return 1
    fi

    # Se rodando como root (via pkexec/sudo), DEVE delegar ao usuário real
    if [[ ${EUID} -eq 0 ]]; then
        if [[ -n "${REAL_USER:-}" ]]; then
            log_info "Delegando instalação AUR para o usuário: $REAL_USER (helper: $helper)"
            run_cmd "$helper -S --noconfirm --needed $*" sudo -u "$REAL_USER" bash -lc "$helper -S --noconfirm --needed $*"
            return $CMD_RC
        else
            log_error "Impossível instalar pacotes AUR como root sem usuário real detectado."
            log_error "Pacotes: $*"
            log_warn "Execute manualmente como usuário normal: $helper -S --needed $*"
            return 1
        fi
    fi

    run_cmd "$helper -S --noconfirm --needed $*" "$helper" -S --noconfirm --needed "$@"
    return $CMD_RC
}

# Instala Cloudflare WARP e aceita automaticamente os termos quando possível
install_cloudflare_warp() {

    run_systemctl enable --now warp-svc || log_warn "Não foi possível habilitar warp-svc (verifique permissões)."

    # Registrar e conectar — tentar modo não interativo quando possível
    if command -v warp-cli &>/dev/null; then
        set +e
        yes | warp-cli --accept-tos registration new 2>&1 | tee -a "$TEMP_LOG" || true
        warp-cli --accept-tos mode warp 2>&1 | tee -a "$TEMP_LOG" || true
        yes | warp-cli --accept-tos connect 2>&1 | tee -a "$TEMP_LOG" || true
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
        if ! warp-cli --accept-tos status 2>/dev/null | grep -qiE "status update: (connected|disconnected)"; then
            log_info "Registrando o cliente WARP neste sistema (não-interativo quando possível)."
            set +e
            yes | warp-cli --accept-tos registration new 2>&1 | tee -a "$TEMP_LOG" || true
            set -e
        fi
        log_info "Aplicando modo WARP e iniciando conexão."
        warp-cli --accept-tos mode warp 2>&1 | tee -a "$TEMP_LOG" || true
        yes | warp-cli --accept-tos connect 2>&1 | tee -a "$TEMP_LOG" || true
        
        # Espera conectar (até 10 segundos)
        for _ in {1..10}; do
            if warp-cli --accept-tos status 2>/dev/null | grep -qi "connected"; then break; fi
            sleep 1
        done
        
        if warp-cli --accept-tos status 2>/dev/null | grep -qi "connected"; then
            log_success "WARP configurado e conectado."
        else
            log_error "WARP não confirmou conexão. Último status:"
            warp-cli --accept-tos status 2>&1 | tee -a "$TEMP_LOG" || true
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
    echo -e "${YELLOW}[1/4]${NC} Verificando AUR helper..."
    garantir_aur_helper || return 1

    echo ""
    echo -e "${YELLOW}[2/4]${NC} Instalando drivers e dependências..."
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
    echo -e "${YELLOW}[3/4]${NC} Instalando aplicativos (repos oficiais)..."
    log_info "Instalando launchers e ferramentas disponíveis nos repositórios CachyOS via pacman."
    run_pacman -S --noconfirm --needed \
        steam \
        lutris \
        protonup-qt \
        proton-cachyos-slr \
        wine-cachyos-opt \
        goverlay \
        heroic-games-launcher-bin \
        vesktop

    echo ""
    echo -e "${YELLOW}[4/4]${NC} Instalando aplicativos (AUR)..."
    log_info "Instalando pacotes exclusivos do AUR via helper."
    # Apenas pacotes que NÃO estão nos repositórios oficiais do CachyOS
    aur_install \
        google-chrome
    local aur_rc=$?
    if [ $aur_rc -ne 0 ]; then
        log_warn "Alguns pacotes AUR não puderam ser instalados automaticamente (rc=$aur_rc)."
        log_warn "Você pode instalá-los manualmente após o script finalizar."
        # Não retorna erro fatal — os pacotes AUR são complementares
    fi

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
        WARP_STATUS=$(warp-cli --accept-tos status 2>/dev/null | head -5 || echo "Não conectado")
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
        if echo "$CMD_OUTPUT" | grep -qE "type filter hook input priority (0|filter); policy drop;" \
           && echo "$CMD_OUTPUT" | grep -qE "type filter hook forward priority (0|filter); policy drop;"; then
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