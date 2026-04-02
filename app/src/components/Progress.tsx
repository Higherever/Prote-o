/**
 * Progress — Equivalente ao gui/ui/progress.go
 *
 * Tela de progresso (Fase 3):
 * - Carrega Loop.gif como animação central (fallback: spinner CSS)
 * - Texto "Aguarde a instalação, estamos trabalhando por você"
 * - Recebe dados do WebSocket via props (conectado no App.tsx)
 * - Ao finalizar: mostra sucesso ou erro
 *
 * CORREÇÃO: Não cria mais sua própria conexão WebSocket.
 * Recebe os dados via props do App.tsx para evitar duplicação.
 */

import { useEffect, useRef, useState } from 'react';
import type { WSMessage } from '../hooks/useWebSocket';

interface ProgressProps {
  funcao: string;
  ws: {
    connected: boolean;
    messages: WSMessage[];
    lastMessage: WSMessage | null;
    clearMessages: () => void;
  };
}

export default function Progress({ funcao, ws }: ProgressProps) {
  const { messages, lastMessage } = ws;
  const [status, setStatus] = useState<'executando' | 'sucesso' | 'erro'>('executando');
  const [textoStatus, setTextoStatus] = useState(
    'Aguarde a instalação, estamos trabalhando por você'
  );
  const [erroMensagem, setErroMensagem] = useState<string | null>(null);
  const [gifCarregado, setGifCarregado] = useState(true);
  const logContainerRef = useRef<HTMLDivElement>(null);

  // Filtra apenas mensagens de output do script
  const logLines = messages
    .filter((m: WSMessage) => m.tipo === 'output' && m.dados)
    .map((m: WSMessage) => m.dados!);

  // Detecta mensagem de finalização
  useEffect(() => {
    if (lastMessage?.tipo === 'finalizado') {
      if (lastMessage.sucesso) {
        setStatus('sucesso');
        setTextoStatus('Instalação concluída com sucesso!');
      } else {
        setStatus('erro');
        setTextoStatus('Erro durante a instalação!');
        setErroMensagem(lastMessage.erro || 'Erro desconhecido');
      }
    }
  }, [lastMessage]);

  // Auto-scroll do log
  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [logLines.length]);

  return (
    <div className="tela-progresso" id="tela-progresso">
      {/* Animação GIF — equivalente a animWidget com Loop.gif */}
      {gifCarregado ? (
        <img
          src="./assets/Loop.gif"
          alt="Animação de instalação"
          className="animacao-progresso"
          onError={() => setGifCarregado(false)}
        />
      ) : (
        // Fallback: spinner CSS quando o GIF não carrega
        <div className="spinner" />
      )}

      {/* Texto de status — equivalente a textoStatus */}
      <p
        className={`texto-progresso ${status === 'sucesso' ? 'sucesso' : ''} ${status === 'erro' ? 'erro' : ''}`}
        id="texto-progresso"
      >
        {textoStatus}
      </p>

      {/* Erro detalhado */}
      {erroMensagem && (
        <p style={{ color: 'var(--color-error)', fontSize: '12px' }}>
          {erroMensagem}
        </p>
      )}

      {/* Log container — exibe output do script em tempo real */}
      {logLines.length > 0 && (
        <div className="log-container" ref={logContainerRef} id="log-output">
          {logLines.map((line, i) => (
            <div key={i} className="log-linha">
              {line}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
