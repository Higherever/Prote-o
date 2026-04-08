"""
Servidor Backend — Equivalente ao gui/main.go

FastAPI com:
- POST /api/executar   — inicia execução de uma função do script
- POST /api/cancelar   — cancela a execução em andamento
- GET  /api/health     — health check para o Electron
- GET  /api/velocidade — retorna a velocidade de download medida
- WS   /ws/progresso   — streaming de logs em tempo real

O frontend React roda no Electron e se conecta aqui via HTTP/WebSocket.
"""

import asyncio
import logging
import os
import signal
import sys

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from logger import configurar_logs
from runner import (
    executar_funcao, esta_executando, obter_erro,
    cancelar_execucao, foi_cancelado,
    medir_velocidade, obter_velocidade,
)

# Configura logs acumulativos — primeiro passo da inicialização
log = configurar_logs()

log.info("[INIT] Módulos importados com sucesso")
log.info("[INIT] Iniciando FastAPI (Proteção Backend)...")

app = FastAPI(title="Proteção Backend")

# CORS para comunicação com Electron/Vite
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ComandoExecutar(BaseModel):
    funcao: str


# Lista de conexões WebSocket ativas
ws_connections: list[WebSocket] = []


@app.get("/api/health")
async def health():
    """Health check — usado pelo Electron para saber quando o backend está pronto."""
    log.debug("[API] /api/health chamado — Electron aguardando backend")
    return {"status": "ok"}


@app.post("/api/executar")
async def api_executar(cmd: ComandoExecutar):
    """Inicia a execução de uma função do script instalar.sh."""
    log.info("[API] POST /api/executar recebido")
    log.info("[API] Requisição para executar: %s", cmd.funcao)

    if esta_executando():
        return {"status": "erro", "mensagem": "Já existe um script em execução"}

    # Callback para enviar output via WebSocket
    async def broadcast_output(msg: dict):
        for ws in ws_connections[:]:
            try:
                await ws.send_json(msg)
            except Exception:
                if ws in ws_connections:
                    ws_connections.remove(ws)

    # Executa em background (não bloqueia a resposta HTTP)
    asyncio.create_task(_executar_e_notificar(cmd.funcao, broadcast_output))

    return {"status": "ok", "mensagem": f"Execução de {cmd.funcao} iniciada"}


@app.post("/api/cancelar")
async def api_cancelar():
    """Cancela a execução atual, se houver."""
    log.info("[API] POST /api/cancelar recebido")
    if not esta_executando():
        return {"status": "erro", "mensagem": "Nenhuma execução em andamento"}

    # BUG-09: Não faz broadcast aqui para evitar evento duplicado.
    # O _executar_e_notificar() já envia {"tipo": "finalizado", "cancelado": true}
    # quando o processo terminar, o que é o evento canônico.
    await cancelar_execucao()

    return {"status": "ok", "mensagem": "Cancelamento solicitado"}


@app.get("/api/velocidade")
async def api_velocidade():
    """Retorna a última velocidade de download medida (bytes/s)."""
    velocidade = obter_velocidade()
    return {
        "velocidade_bytes_s": velocidade,
        "velocidade_kbps": round(velocidade / 1024, 1),
        "velocidade_mbps": round(velocidade / (1024 * 1024), 2),
    }




async def _executar_e_notificar(funcao: str, broadcast):
    """Wrapper que mede a velocidade, executa a função e notifica via WebSocket."""
    # Mede velocidade de download antes de iniciar a instalação
    velocidade = await medir_velocidade()
    await broadcast({
        "tipo": "velocidade",
        "bytes_por_segundo": velocidade,
        "kbps": round(velocidade / 1024, 1),
    })

    await executar_funcao(funcao, on_output=broadcast)

    # Notifica finalização para todos os WebSockets conectados
    erro = obter_erro()
    cancelado = foi_cancelado()

    for ws in ws_connections[:]:
        try:
            await ws.send_json(
                {
                    "tipo": "finalizado",
                    "sucesso": erro is None and not cancelado,
                    "erro": erro,
                    "cancelado": cancelado
                }
            )
        except Exception:
            if ws in ws_connections:
                ws_connections.remove(ws)


@app.websocket("/ws/progresso")
async def websocket_progresso(websocket: WebSocket):
    """WebSocket para streaming de progresso em tempo real."""
    await websocket.accept()
    ws_connections.append(websocket)
    log.info("[WS] Nova conexão WebSocket estabelecida")

    try:
        while True:
            # Recebe mensagens do frontend (ping, status checks)
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_json({"tipo": "pong"})
            elif data == "status":
                await websocket.send_json(
                    {
                        "tipo": "status",
                        "executando": esta_executando(),
                        "erro": obter_erro(),
                    }
                )
    except WebSocketDisconnect:
        log.info("[WS] Conexão WebSocket encerrada")
        if websocket in ws_connections:
            ws_connections.remove(websocket)
    except Exception as e:
        log.error("[WS] Erro na conexão WebSocket: %s", e)
        if websocket in ws_connections:
            ws_connections.remove(websocket)


def handle_sigterm(*args):
    """Encerra graciosamente ao receber SIGTERM."""
    log.info("[SHUTDOWN] Sinal de encerramento recebido (SIGTERM/SIGINT)")
    log.info("[SHUTDOWN] Backend FastAPI finalizado.")
    log.info("=" * 60)
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGINT, handle_sigterm)

    port = int(os.environ.get("PROTECAO_PORT", "8000"))
    log.info("[INIT] Servidor backend iniciando na porta %d", port)
    log.info("[INIT] Endereço: http://127.0.0.1:%d", port)
    log.info("[INIT] Health check disponível em: /api/health")
    log.info("[INIT] WebSocket disponível em: /ws/progresso")

    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")
