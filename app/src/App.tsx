/**
 * App.tsx — Componente principal do Proteção GUI
 *
 * Gerencia o layout principal e as 3 fases da aplicação:
 * Fase 1: Boas-vindas (vídeo de transição e animação)
 * Fase 2: Opções (fundo estático Complexity e menu Glassmorphism)
 * Fase 3: Progresso (reprodução contínua e status via WebSocket)
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import TitleBar from './components/TitleBar';
import Welcome from './components/Welcome';
import Options from './components/Options';
import Progress from './components/Progress';
import { useWebSocket } from './hooks/useWebSocket';

type Fase = 'boas-vindas' | 'opcoes' | 'progresso';

export default function App() {
  const [faseAtual, setFaseAtual] = useState<Fase>('boas-vindas');
  const [funcaoEscolhida, setFuncaoEscolhida] = useState<string>('');
  
  // Ref para controlar play/pause do vídeo de background Global
  const bgVideoRef = useRef<HTMLVideoElement>(null);

  const ws = useWebSocket();

  // Controla o play/pause do bg video reativamente quando a fase muda
  useEffect(() => {
    if (bgVideoRef.current) {
      if (faseAtual === 'opcoes') {
        bgVideoRef.current.currentTime = 0; // reseta ao começo
        bgVideoRef.current.pause();
      } else if (faseAtual === 'progresso') {
        bgVideoRef.current.play().catch(e => console.error("Play background video error:", e));
      }
    }
  }, [faseAtual]);

  const aoFinalizarBoasVindas = useCallback(() => {
    setFaseAtual('opcoes');
  }, []);

  const aoEscolherOpcao = useCallback((funcao: string) => {
    setFuncaoEscolhida(funcao);
    setFaseAtual('progresso');
  }, []);

  return (
    <div id="janela-principal">
      <TitleBar />

      {/* Global Background Video injetado por trás da interface nas fases de opção e progresso */}
      {(faseAtual === 'opcoes' || faseAtual === 'progresso') && (
        <video
          ref={bgVideoRef}
          src="./videos/loading.mp4"
          loop
          muted
          playsInline
          className="global-bg-video"
        />
      )}

      <div className="conteudo-principal">
        <div className="container-fases">
          {faseAtual === 'boas-vindas' && (
            <Welcome onComplete={aoFinalizarBoasVindas} />
          )}
          {faseAtual === 'opcoes' && (
            <Options onSelect={aoEscolherOpcao} />
          )}
          {faseAtual === 'progresso' && (
            <Progress funcao={funcaoEscolhida} ws={ws} />
          )}
        </div>
      </div>
    </div>
  );
}
