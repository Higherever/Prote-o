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
import time
from typing import Optional, Callable, Awaitable, Union

# Regex para remover códigos de escape ANSI (cores do terminal)
_ANSI_ESCAPE = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')

logger = logging.getLogger("protecao")

# Estado do processo (protegido por lock assíncrono)
_processo: Optional[asyncio.subprocess.Process] = None
_executando: bool = False
_erro_final: Optional[str] = None
_cancelado: bool = False
_ultimo_output: float = 0.0
_velocidade_download: float = 0.0
_lock = asyncio.Lock()

# Timeout padrão (segundos) sem output antes de emitir aviso.
# É ajustado dinamicamente com base na velocidade de download.
TIMEOUT_BASE_SEGUNDOS = 120
TIMEOUT_LENTO_SEGUNDOS = 300  # para conexões < 500 KB/s


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
    on_output: Optional[Callable[[Union[str, dict]], Awaitable[None]]] = None,
) -> None:
    """
    Executa uma função específica do script Bash em segundo plano via pkexec.

    Equivalente direto do ExecutarFuncao() em runner.go.
    Usa PROTECAO_RUN_FUNC para evitar o menu interativo.

    Args:
        nome_funcao: Nome da função bash (instalar_seguranca, instalar_jogos, etc.)
        on_output: Callback assíncrono chamado para cada linha de saída do script.
    """
    global _processo, _executando, _erro_final, _cancelado, _ultimo_output

    async with _lock:
        if _executando:
            logger.warning("Já existe um script em execução")
            return
        _executando = True
        _erro_final = None
        _cancelado = False
        _ultimo_output = time.time()

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

        # Inicia watchdog de timeout em paralelo
        watchdog_task = asyncio.create_task(_watchdog(on_output))

        # Lê stdout linha a linha e envia via callback
        assert proc.stdout is not None
        while True:
            line = await proc.stdout.readline()
            if not line:
                break
            _ultimo_output = time.time()
            decoded = _ANSI_ESCAPE.sub('', line.decode("utf-8", errors="replace").rstrip())
            logger.info("[SCRIPT] %s", decoded)
            if on_output:
                try:
                    if decoded.startswith("###PROTEO:"):
                        # BUG-08: limitar splits e validar índices antes de acessar
                        partes = decoded.split(":", 4)
                        if len(partes) >= 2 and partes[1] == "ETAPA" and len(partes) >= 5:
                            try:
                                msg = {"tipo": "etapa", "etapa": partes[2], "numero": int(partes[3]), "total": int(partes[4]), "tempo_inicio": time.time()}
                                await on_output(msg)
                            except (ValueError, IndexError) as parse_err:
                                logger.warning("[PARSER] Marcador ETAPA malformado: %s — %s", decoded, parse_err)
                        elif len(partes) >= 3 and partes[1] == "PKG":
                            msg = {"tipo": "pacote", "pacote": partes[2]}
                            await on_output(msg)
                        elif len(partes) >= 3 and partes[1] == "FIM_ETAPA":
                            msg = {"tipo": "fim_etapa", "etapa": partes[2]}
                            await on_output(msg)
                    else:
                        await on_output({"tipo": "output", "dados": decoded})
                except Exception:
                    pass

        # Cancela o watchdog agora que o processo terminou
        watchdog_task.cancel()
        try:
            await watchdog_task
        except asyncio.CancelledError:
            pass

        # BUG-03: proc já terminou (readline retornou b''), mas garantimos coleta do exit code
        try:
            await asyncio.wait_for(proc.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass

        # BUG-09: não registra erro se o processo foi cancelado intencionalmente
        if proc.returncode != 0:
            if not _cancelado:
                _erro_final = f"Script retornou código {proc.returncode}"
                logger.error("Erro na execução do script: %s", _erro_final)
            else:
                logger.info("Script encerrado por cancelamento do usuário (código %d).", proc.returncode)
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

async def cancelar_execucao():
    """Tenta cancelar o processo em andamento."""
    # BUG-02: separar a espera do proc.wait() de fora do _lock para evitar deadlock.
    # O finally de executar_funcao() também usa _lock para liberar _executando=False,
    # então não podemos segurar o lock enquanto aguardamos o processo terminar.
    global _cancelado
    proc_a_matar = None
    async with _lock:
        if _processo and _executando:
            _cancelado = True
            proc_a_matar = _processo

    if proc_a_matar:
        logger.info("Cancelando execução (enviando SIGTERM)...")
        proc_a_matar.terminate()
        try:
            await asyncio.wait_for(proc_a_matar.wait(), timeout=5)
        except asyncio.TimeoutError:
            logger.warning("Tempo limite esgotado, enviando SIGKILL...")
            proc_a_matar.kill()

def foi_cancelado() -> bool:
    """Retorna True se a execução atual foi cancelada pelo usuário."""
    return _cancelado


async def medir_velocidade() -> float:
    """
    Mede a velocidade de download (bytes/s) usando curl contra um mirror do pacman.
    Retorna o valor em bytes/s. Fallback para 500KB/s em caso de falha.
    """
    global _velocidade_download
    try:
        proc = await asyncio.create_subprocess_exec(
            "curl", "-o", "/dev/null", "-w", "%{speed_download}",
            "--max-time", "10", "-s",
            "https://geo.mirror.pkgbuild.com/core/os/x86_64/core.db",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        velocidade = float(stdout.decode().strip())
        _velocidade_download = velocidade
        logger.info("[VELOCIDADE] Download medido: %.0f bytes/s (%.1f KB/s)", velocidade, velocidade / 1024)
        return velocidade
    except Exception as e:
        logger.warning("[VELOCIDADE] Falha ao medir velocidade: %s — usando fallback 500 KB/s", e)
        _velocidade_download = 500_000
        return _velocidade_download


def obter_velocidade() -> float:
    """Retorna a última velocidade medida em bytes/s."""
    return _velocidade_download


def _calcular_timeout() -> int:
    """Calcula o timeout adaptativo baseado na velocidade de download."""
    if _velocidade_download <= 0:
        return TIMEOUT_BASE_SEGUNDOS
    if _velocidade_download < 500_000:  # < 500 KB/s
        return TIMEOUT_LENTO_SEGUNDOS
    return TIMEOUT_BASE_SEGUNDOS


async def _watchdog(
    on_output: Optional[Callable[[Union[str, dict]], Awaitable[None]]] = None,
) -> None:
    """
    Task paralela que monitora a atividade do stdout do processo.
    Se não houver output por mais de `timeout` segundos, emite um
    evento `timeout_warning` via callback — mas NÃO cancela o processo.
    A decisão de cancelar fica com o frontend/usuário.
    """
    _aviso_emitido = False
    try:
        while _executando:
            await asyncio.sleep(5)
            if not _executando:
                break
            silencio = time.time() - _ultimo_output
            timeout = _calcular_timeout()
            if silencio > timeout and on_output and not _aviso_emitido:
                _aviso_emitido = True
                logger.warning(
                    "[WATCHDOG] Sem output há %.0f segundos (timeout: %d s)",
                    silencio, timeout,
                )
                try:
                    await on_output({
                        "tipo": "timeout_warning",
                        "segundos_sem_resposta": int(silencio),
                        "timeout_configurado": timeout,
                    })
                except Exception:
                    pass
            # Reseta aviso quando output volta
            elif silencio <= timeout:
                _aviso_emitido = False
    except asyncio.CancelledError:
        return
