/**
 * useWebSocket — Hook personalizado para gerenciar conexão WebSocket
 *
 * Conecta ao backend Python em ws://127.0.0.1:8000/ws/progresso
 * e recebe linhas de output do script em tempo real.
 */

import { useEffect, useRef, useState, useCallback } from 'react';

const WS_BASE = 'ws://127.0.0.1:8000';

export interface WSMessage {
  tipo: 'output' | 'finalizado' | 'pong' | 'status';
  dados?: string;
  sucesso?: boolean;
  erro?: string | null;
  executando?: boolean;
}

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const [connected, setConnected] = useState(false);
  const [messages, setMessages] = useState<WSMessage[]>([]);
  const [lastMessage, setLastMessage] = useState<WSMessage | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout>>();

  const connect = useCallback(() => {
    // Limpa timer anterior
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current);
    }

    try {
      const ws = new WebSocket(`${WS_BASE}/ws/progresso`);
      wsRef.current = ws;

      ws.onopen = () => {
        console.log('[WS] Conectado ao backend');
        setConnected(true);
      };

      ws.onclose = () => {
        console.log('[WS] Desconectado. Reconectando em 2s...');
        setConnected(false);
        // Reconexão automática
        reconnectTimer.current = setTimeout(connect, 2000);
      };

      ws.onerror = (err) => {
        console.error('[WS] Erro:', err);
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data) as WSMessage;
          setLastMessage(msg);
          setMessages((prev) => [...prev, msg]);
        } catch {
          console.error('[WS] Mensagem inválida:', event.data);
        }
      };
    } catch (err) {
      console.error('[WS] Falha ao conectar:', err);
      reconnectTimer.current = setTimeout(connect, 2000);
    }
  }, []);

  useEffect(() => {
    connect();
    return () => {
      if (reconnectTimer.current) {
        clearTimeout(reconnectTimer.current);
      }
      wsRef.current?.close();
    };
  }, [connect]);

  /** Limpa o histórico de mensagens */
  const clearMessages = useCallback(() => {
    setMessages([]);
    setLastMessage(null);
  }, []);

  return { connected, messages, lastMessage, clearMessages };
}
