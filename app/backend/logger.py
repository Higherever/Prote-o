"""
Sistema de Logging Acumulativo — Proteção GUI

Regras:
  - Cada abertura do programa gera um novo arquivo de log com timestamp.
  - O diretório logs/logFront/ armazena no máximo 10 arquivos.
    Quando o limite é excedido, o arquivo MAIS ANTIGO é excluído automaticamente.
  - Na inicialização, o log registra informações do sistema:
    OS, versão, kernel, e servidor gráfico (Wayland ou X11).
  - Todas as interações e eventos do programa são registrados.
"""

import logging
import os
import platform
import subprocess
from datetime import datetime
from pathlib import Path

# Limite máximo de arquivos de log por categoria
MAX_LOGS = 10


def _coletar_info_sistema() -> dict:
    """
    Coleta informações básicas do sistema operacional e ambiente gráfico.
    Retorna um dicionário com os dados coletados.
    """
    info = {}

    # --- Sistema Operacional ---
    info["os_nome"] = platform.system()  # ex: 'Linux'
    info["os_release"] = platform.release()  # ex: '6.14.0-1-cachyos'
    info["os_version"] = platform.version()  # descrição completa

    # Tenta ler /etc/os-release para nome distro (ex: CachyOS, Arch Linux)
    try:
        os_release_path = Path("/etc/os-release")
        if os_release_path.exists():
            data = {}
            for line in os_release_path.read_text().splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    data[k.strip()] = v.strip().strip('"')
            info["distro_nome"] = data.get("NAME", "Desconhecido")
            info["distro_versao"] = data.get("VERSION", data.get("VERSION_ID", "N/A"))
        else:
            info["distro_nome"] = "Desconhecido"
            info["distro_versao"] = "N/A"
    except Exception:
        info["distro_nome"] = "Erro ao ler"
        info["distro_versao"] = "N/A"

    # --- Kernel ---
    try:
        info["kernel"] = subprocess.check_output(
            ["uname", "-r"], text=True, timeout=3
        ).strip()
    except Exception:
        info["kernel"] = platform.release()

    # --- Interface Gráfica: Wayland ou X11 ---
    wayland_display = os.environ.get("WAYLAND_DISPLAY", "")
    xdg_session = os.environ.get("XDG_SESSION_TYPE", "").lower()
    display = os.environ.get("DISPLAY", "")

    if wayland_display or xdg_session == "wayland":
        info["display_server"] = f"Wayland ({wayland_display or xdg_session})"
    elif display or xdg_session == "x11":
        info["display_server"] = f"X11 ({display or xdg_session})"
    else:
        info["display_server"] = "Desconhecido (sem DISPLAY nem WAYLAND_DISPLAY)"

    # --- Compositor / Desktop Environment ---
    info["desktop"] = os.environ.get(
        "XDG_CURRENT_DESKTOP",
        os.environ.get("DESKTOP_SESSION", "Desconhecido"),
    )

    # --- Arquitetura da máquina ---
    info["arquitetura"] = platform.machine()  # ex: 'x86_64'

    return info


def _limpar_logs_antigos(diretorio: Path, prefixo: str, extensao: str = ".log") -> None:
    """
    Garante que o diretório tenha no máximo MAX_LOGS arquivos com o prefixo dado.
    Se o limite for excedido, os arquivos mais antigos são excluídos.
    """
    arquivos = sorted(
        diretorio.glob(f"{prefixo}*{extensao}"),
        key=lambda f: f.stat().st_mtime,  # ordena por data de modificação
    )

    excedente = len(arquivos) - (MAX_LOGS - 1)  # reserva espaço para o novo log
    if excedente > 0:
        for arquivo_antigo in arquivos[:excedente]:
            try:
                arquivo_antigo.unlink()
            except OSError:
                pass


def configurar_logs() -> logging.Logger:
    """
    Configura o sistema de logs acumulativos.
    Logs são salvos em: Prote-o/logs/logFront/app_YYYYMMDD_HHMMSS.log

    Aplica limite de MAX_LOGS (10) arquivos por categoria — o mais antigo
    é excluído automaticamente quando o limite é ultrapassado.

    Retorna o logger configurado.
    """
    logger = logging.getLogger("protecao")

    # Evita duplicação se chamado mais de uma vez
    if logger.handlers:
        return logger

    # Encontra o diretório base do projeto (Prote-o/)
    # backend/ está em app/backend/, então subimos 2 níveis
    base_dir = Path(__file__).resolve().parent.parent.parent

    log_front_dir = base_dir / "logs" / "logFront"
    log_front_dir.mkdir(parents=True, exist_ok=True)

    # Remove logs mais antigos antes de criar o novo (limite = MAX_LOGS)
    _limpar_logs_antigos(log_front_dir, prefixo="app_")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_front_dir / f"app_{timestamp}.log"

    # Formato do log
    formatter = logging.Formatter(
        "[%(asctime)s] %(levelname)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Handler de arquivo — log persistente
    file_handler = logging.FileHandler(str(log_file), encoding="utf-8")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    # Handler de console — saída padrão
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)

    logger.setLevel(logging.DEBUG)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    # ── Registro de início de sessão ──────────────────────────────────────
    logger.info("=" * 60)
    logger.info("  PROTEÇÃO GUI — INÍCIO DE SESSÃO")
    logger.info("=" * 60)
    logger.info("[INIT] Timestamp de abertura: %s", datetime.now().isoformat())
    logger.info("[INIT] Arquivo de log ativo: %s", log_file)
    logger.info("[INIT] Limite de logs por categoria: %d arquivos", MAX_LOGS)

    # ── Informações do sistema ─────────────────────────────────────────────
    try:
        info = _coletar_info_sistema()
        logger.info("-" * 60)
        logger.info("[SISTEMA] === Informações do Ambiente ===")
        logger.info("[SISTEMA] Distribuição : %s %s", info["distro_nome"], info["distro_versao"])
        logger.info("[SISTEMA] Kernel       : %s", info["kernel"])
        logger.info("[SISTEMA] OS Base      : %s %s", info["os_nome"], info["os_release"])
        logger.info("[SISTEMA] Arquitetura  : %s", info["arquitetura"])
        logger.info("[SISTEMA] Display/GUI  : %s", info["display_server"])
        logger.info("[SISTEMA] Desktop Env  : %s", info["desktop"])
        logger.info("-" * 60)
    except Exception as e:
        logger.warning("[SISTEMA] Não foi possível coletar informações do sistema: %s", e)

    logger.info("[INIT] Backend FastAPI inicializando...")

    return logger
