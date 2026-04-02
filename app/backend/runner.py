"""
Executor do Script — Equivalente ao gui/script/runner.go

Executa funções do instalar.sh via pkexec (elevação de privilégios Polkit).
Usa asyncio.create_subprocess_exec para captura de stdout em tempo real.
A variável de ambiente PROTECAO_RUN_FUNC instrui o script a executar
apenas a função desejada, sem exibir o menu interativo.
"""

import asyncio
import logging
import re
from pathlib import Path
from typing import Optional, Callable, Awaitable

# Regex para remover códigos de escape ANSI (cores do terminal)
_ANSI_ESCAPE = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')

logger = logging.getLogger("protecao")

# Estado do processo (protegido por lock assíncrono)
_processo: Optional[asyncio.subprocess.Process] = None
_executando: bool = False
_erro_final: Optional[str] = None
_lock = asyncio.Lock()


def _resolver_caminho_script() -> str:
    """Resolve o caminho do instalar.sh relativo ao projeto."""
    # backend/ está em app/backend/, instalar.sh está em Prote-o/
    base_dir = Path(__file__).resolve().parent.parent.parent
    caminho = base_dir / "instalar.sh"

    if not caminho.exists():
        logger.error(
            "[ERRO CRÍTICO] Script instalar.sh não encontrado em: %s", caminho
        )
        logger.error("Certifique-se de executar do local correto.")
    else:
        logger.info("[INFO] Caminho do script resolvido: %s", caminho)

    return str(caminho)


CAMINHO_SCRIPT = _resolver_caminho_script()


async def executar_funcao(
    nome_funcao: str,
    on_output: Optional[Callable[[str], Awaitable[None]]] = None,
) -> None:
    """
    Executa uma função específica do script Bash em segundo plano via pkexec.

    Equivalente direto do ExecutarFuncao() em runner.go.
    Usa PROTECAO_RUN_FUNC para evitar o menu interativo.

    Args:
        nome_funcao: Nome da função bash (instalar_seguranca, instalar_jogos, etc.)
        on_output: Callback assíncrono chamado para cada linha de saída do script.
    """
    global _processo, _executando, _erro_final

    async with _lock:
        if _executando:
            logger.warning("Já existe um script em execução")
            return
        _executando = True
        _erro_final = None

    # Monta o comando: pkexec bash -c "PROTECAO_RUN_FUNC='funcao' bash 'instalar.sh'"
    comando_bash = f"PROTECAO_RUN_FUNC='{nome_funcao}' bash '{CAMINHO_SCRIPT}'"
    logger.info('Executando: pkexec bash -c "%s"', comando_bash)

    try:
        proc = await asyncio.create_subprocess_exec(
            "pkexec",
            "bash",
            "-c",
            comando_bash,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        _processo = proc

        # Lê stdout linha a linha e envia via callback
        assert proc.stdout is not None
        while True:
            line = await proc.stdout.readline()
            if not line:
                break
            decoded = _ANSI_ESCAPE.sub('', line.decode("utf-8", errors="replace").rstrip())
            logger.info("[SCRIPT] %s", decoded)
            if on_output:
                try:
                    await on_output(decoded)
                except Exception:
                    pass

        await proc.wait()

        if proc.returncode != 0:
            _erro_final = f"Script retornou código {proc.returncode}"
            logger.error("Erro na execução do script: %s", _erro_final)
        else:
            logger.info("Script finalizado com sucesso.")

    except Exception as e:
        _erro_final = str(e)
        logger.error("Exceção ao executar script: %s", e)

    finally:
        async with _lock:
            _executando = False
            _processo = None


def esta_executando() -> bool:
    """Retorna True se há um script rodando no momento."""
    return _executando


def obter_erro() -> Optional[str]:
    """Retorna o erro da última execução (None se não houve erro)."""
    return _erro_final
