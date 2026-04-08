/**
 * useWebSocket — Hook personalizado para gerenciar conexão WebSocket
 *
 * Conecta ao backend Python em ws://127.0.0.1:8000/ws/progresso
 * e recebe eventos estruturados do script em tempo real.
 *
 * Tipos de evento suportados:
 * - output        : linha de log bruta do script
 * - etapa         : início de uma etapa de instalação
 * - pacote        : um pacote está sendo processado
 * - fim_etapa     : uma etapa concluiu
 * - velocidade    : medição de velocidade de download
 * - timeout_warning : o watchdog detectou silêncio prolongado
 * - cancelado     : a execução foi cancelada pelo usuário
 * - finalizado    : a execução terminou (com sucesso, erro ou cancelamento)
 * - pong / status : respostas a heartbeat e consulta de estado
 */

import { useEffect, useRef, useState, useCallback } from 'react';

const WS_BASE = 'ws://127.0.0.1:8000';

export interface WSMessage {
  tipo:
    | 'output'
    | 'etapa'
    | 'pacote'
    | 'fim_etapa'
    | 'velocidade'
    | 'timeout_warning'
    | 'cancelado'
    | 'finalizado'
    | 'pong'
    | 'status';
  /* output */
  dados?: string;
  /* etapa */
  etapa?: string;
  numero?: number;
  total?: number;
  tempo_inicio?: number;
  /* pacote */
  pacote?: string;
  /* velocidade */
  bytes_por_segundo?: number;
  kbps?: number;
  /* timeout_warning */
  segundos_sem_resposta?: number;
  timeout_configurado?: number;
  /* finalizado */
  sucesso?: boolean;
  erro?: string | null;
  cancelado?: boolean;
  /* status */
  executando?: boolean;
}

/** Status possível de um pacote na lista visual */
export type StatusPacote = 'aguardando' | 'instalando' | 'concluido' | 'erro';

/** Dados de um pacote rastreado pela UI */
export interface PacoteInfo {
  nome: string;
  status: StatusPacote;
  tempoInicio?: number;
  tempoFim?: number;
}

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const [connected, setConnected] = useState(false);
  const [messages, setMessages] = useState<WSMessage[]>([]);
  const [lastMessage, setLastMessage] = useState<WSMessage | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

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
