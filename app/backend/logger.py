"""
Sistema de Logging Acumulativo — Equivalente ao gui/logger/logger.go

Cada vez que o programa é aberto, um novo arquivo de log é criado em
logs/logFront/ com timestamp no nome (app_YYYYMMDD_HHMMSS.log).

Todas as interações e erros do programa são registrados automaticamente.
"""

import logging
import os
from datetime import datetime
from pathlib import Path


def configurar_logs() -> logging.Logger:
    """
    Configura o sistema de logs acumulativos.
    Logs são salvos em: Prote-o/logs/logFront/app_YYYYMMDD_HHMMSS.log

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

    logger.info("--- Início da Sessão da Interface Gráfica ---")
    logger.info("Logs sendo gravados cumulativamente em: %s", log_file)

    return logger
