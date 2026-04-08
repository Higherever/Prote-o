/**
 * Progress — Tela de Progresso (Fase 3) — Refatorada
 *
 * Layout novo:
 * ┌─────────────────────────────────────┐
 * │  [Loading26]                        │
 * │  "Instalando Proteção e Segurança"  │
 * │                                     │
 * │  Etapa 2/5 — Cloudflare WARP  1:23  │
 * │  ████████████░░░░░░░  40%           │
 * │                                     │
 * │  ✅ nftables         ⏱ 0:12        │
 * │  ⬇️ cloudflare-warp  ⏱ 0:34        │
 * │  ⏳ fail2ban                        │
 * │                                     │
 * │  ▼ Log detalhado (colapsável)       │
 * │                                     │
 * │  Tempo total: 3:45                  │
 * │  [🔴 Cancelar Instalação]          │
 * └─────────────────────────────────────┘
 *
 * Consome novos eventos WS: etapa, pacote, fim_etapa, velocidade,
 * timeout_warning, cancelado, finalizado.
 */

import { useEffect, useRef, useState, useCallback } from 'react';
import type { WSMessage, PacoteInfo } from '../hooks/useWebSocket';
import { useTimer } from '../hooks/useTimer';
import Loading26 from './Loading26';
import ProgressHeader from './ProgressHeader';
import PackageList from './PackageList';

interface ProgressProps {
  funcao: string;
  ws: {
    connected: boolean;
    messages: WSMessage[];
    lastMessage: WSMessage | null;
    clearMessages: () => void;
  };
  onBack: () => void;
  saindo: boolean;
}

/** Mapeia nome da função bash ao título exibido ao usuário (BUG-10) */
const TITULOS_FUNCAO: Record<string, string> = {
  instalar_seguranca: 'Instalando Proteção e Segurança',
  instalar_jogos: 'Instalando Ambiente de Jogos',
  configuracao_completa: 'Instalação Completa do Sistema',
};

type Status = 'executando' | 'sucesso' | 'erro' | 'cancelado';

export default function Progress({ funcao, ws, onBack, saindo }: ProgressProps) {
  const { messages, lastMessage } = ws;

  // Estado geral
  const [status, setStatus] = useState<Status>('executando');
  const [textoStatus, setTextoStatus] = useState(
    // BUG-10: usa o título específico da função escolhida
    TITULOS_FUNCAO[funcao] || 'Aguarde a instalação, estamos trabalhando por você'
  );
  const [erroMensagem, setErroMensagem] = useState<string | null>(null);

  // Estado da etapa atual
  const [etapaAtual, setEtapaAtual] = useState('Preparando...');
  const [etapaNumero, setEtapaNumero] = useState(0);
  const [etapaTotal, setEtapaTotal] = useState(0);

  // Pacotes
  const [pacotes, setPacotes] = useState<PacoteInfo[]>([]);

  // Log colapsável
  const [logAberto, setLogAberto] = useState(false);
  const logContainerRef = useRef<HTMLDivElement>(null);

  // Cronômetros
  const timerGlobal = useTimer();
  const timerEtapa = useTimer();

  // Modal de confirmação de cancelamento
  const [showConfirm, setShowConfirm] = useState(false);

  // Modal de timeout warning
  const [showTimeoutWarning, setShowTimeoutWarning] = useState(false);
  const [timeoutSegundos, setTimeoutSegundos] = useState(0);

  // Velocidade
  const [velocidadeKbps, setVelocidadeKbps] = useState<number | null>(null);

  // Filtra linhas de log brutas
  const logLines = messages
    .filter((m: WSMessage) => m.tipo === 'output' && m.dados)
    .map((m: WSMessage) => m.dados!);

  // BUG-04: Inicia a instalação ao montar o componente.
  // A prop 'funcao' estava sendo recebida mas nunca enviada ao backend.
  useEffect(() => {
    if (!funcao) return;
    fetch('http://127.0.0.1:8000/api/executar', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ funcao }),
    }).catch(err => console.error('[Progress] Erro ao iniciar execução:', err));
    // Executa APENAS na montagem — sem dependência de 'funcao' para não re-disparar
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Inicia timer global ao montar
  useEffect(() => {
    timerGlobal.start();
    return () => timerGlobal.stop();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Processa cada mensagem WebSocket
  useEffect(() => {
    if (!lastMessage) return;

    switch (lastMessage.tipo) {
      case 'etapa':
        setEtapaAtual(lastMessage.etapa || '');
        setEtapaNumero(lastMessage.numero || 0);
        setEtapaTotal(lastMessage.total || 0);
        // Reset do timer da etapa e da lista de pacotes
        timerEtapa.reset();
        timerEtapa.start();
        setPacotes([]);
        break;

      case 'pacote': {
        const nomePkg = lastMessage.pacote || '';
        setPacotes((prev) => {
          // Marca o anterior como concluído
          const atualizado = prev.map((p) =>
            p.status === 'instalando'
              ? { ...p, status: 'concluido' as const, tempoFim: Date.now() / 1000 }
              : p
          );
          // Adiciona o novo como instalando
          return [
            ...atualizado,
            { nome: nomePkg, status: 'instalando', tempoInicio: Date.now() / 1000 },
          ];
        });
        break;
      }

      case 'fim_etapa':
        timerEtapa.stop();
        // Marca todos os pacotes pendentes como concluídos
        setPacotes((prev) =>
          prev.map((p) =>
            p.status === 'instalando'
              ? { ...p, status: 'concluido' as const, tempoFim: Date.now() / 1000 }
              : p
          )
        );
        break;

      case 'velocidade':
        setVelocidadeKbps(lastMessage.kbps ?? null);
        break;

      case 'timeout_warning':
        setTimeoutSegundos(lastMessage.segundos_sem_resposta || 0);
        setShowTimeoutWarning(true);
        break;

      case 'cancelado':
        setStatus('cancelado');
        setTextoStatus('Instalação cancelada pelo usuário.');
        timerGlobal.stop();
        timerEtapa.stop();
        break;

      case 'finalizado':
        timerGlobal.stop();
        timerEtapa.stop();
        if (lastMessage.cancelado) {
          setStatus('cancelado');
          setTextoStatus('Instalação cancelada pelo usuário.');
        } else if (lastMessage.sucesso) {
          setStatus('sucesso');
          setTextoStatus('Instalação concluída com sucesso!');
        } else {
          setStatus('erro');
          setTextoStatus('Erro durante a instalação!');
          setErroMensagem(lastMessage.erro || 'Erro desconhecido');
        }
        break;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lastMessage]);

  // Auto-scroll do log
  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [logLines.length]);

  // Handler de cancelamento
  const handleCancelar = useCallback(async () => {
    try {
      await fetch('http://127.0.0.1:8000/api/cancelar', { method: 'POST' });
    } catch (err) {
      console.error('[Progress] Erro ao cancelar:', err);
    }
    setShowConfirm(false);
  }, []);

  return (
    <div className={`tela-progresso ${saindo ? 'saindo' : ''}`} id="tela-progresso">
      {/* Animação Loading durante execução */}
      {status === 'executando' && <Loading26 />}

      {/* Texto de status */}
      <p
        className={`texto-progresso ${status === 'sucesso' ? 'sucesso' : ''} ${status === 'erro' ? 'erro' : ''} ${status === 'cancelado' ? 'cancelado' : ''}`}
        id="texto-progresso"
      >
        {textoStatus}
      </p>

      {/* Velocidade de download */}
      {velocidadeKbps !== null && status === 'executando' && (
        <p className="texto-velocidade">
          📶 Velocidade: {velocidadeKbps.toFixed(1)} KB/s
        </p>
      )}

      {/* Cabeçalho da etapa com barra de progresso */}
      {status === 'executando' && etapaTotal > 0 && (
        <ProgressHeader
          etapa={etapaAtual}
          numero={etapaNumero}
          total={etapaTotal}
          tempoEtapa={timerEtapa.formatted}
        />
      )}

      {/* Lista visual de pacotes */}
      {status === 'executando' && <PackageList pacotes={pacotes} />}

      {/* Erro detalhado */}
      {erroMensagem && (
        <p className="texto-erro-detalhe">
          {erroMensagem}
        </p>
      )}

      {/* Toggle para log detalhado */}
      {logLines.length > 0 && (
        <div className="log-toggle-wrapper">
          <button
            className="log-toggle-btn"
            onClick={() => setLogAberto(!logAberto)}
            id="btn-toggle-log"
          >
            {logAberto ? '▲ Ocultar log detalhado' : '▼ Ver log detalhado'}
          </button>

          {logAberto && (
            <div className="log-container" ref={logContainerRef} id="log-output">
              {logLines.map((line, i) => (
                <div key={i} className="log-linha">
                  {line}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Rodapé: tempo total + cancelar */}
      <div className="progress-footer">
        <span className="progress-tempo-total">
          Tempo total: {timerGlobal.formatted}
        </span>

        {status === 'executando' && (
          <button
            className="btn-opcao btn-cancelar"
            onClick={() => setShowConfirm(true)}
            id="btn-cancelar"
          >
            🔴 Cancelar Instalação
          </button>
        )}

        {status !== 'executando' && (
          <button
            className="btn-opcao btn-voltar"
            onClick={onBack}
            id="btn-voltar"
          >
            ⬅️ Voltar para Opções
          </button>
        )}
      </div>

      {/* Modal de confirmação de cancelamento */}
      {showConfirm && (
        <div className="modal-overlay" id="modal-cancelar">
          <div className="modal-confirmacao">
            <p className="modal-texto">
              Tem certeza? Pacotes podem ficar parcialmente instalados.
            </p>
            <div className="modal-botoes">
              <button className="btn-opcao btn-confirmar-cancelar" onClick={handleCancelar}>
                Sim, cancelar
              </button>
              <button className="btn-opcao btn-continuar" onClick={() => setShowConfirm(false)}>
                Continuar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de timeout warning */}
      {showTimeoutWarning && (
        <div className="modal-overlay" id="modal-timeout">
          <div className="modal-confirmacao">
            <p className="modal-texto">
              ⚠️ Sem resposta há {timeoutSegundos} segundos. O que deseja fazer?
            </p>
            <div className="modal-botoes">
              <button
                className="btn-opcao btn-confirmar-cancelar"
                onClick={() => { setShowTimeoutWarning(false); handleCancelar(); }}
              >
                Cancelar instalação
              </button>
              <button
                className="btn-opcao btn-continuar"
                onClick={() => setShowTimeoutWarning(false)}
              >
                Continuar esperando
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
