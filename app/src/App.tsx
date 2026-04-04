/**
 * App.tsx — Componente principal do Proteção GUI
 *
 * Gerencia o layout principal e as 3 fases da aplicação:
 * Fase 1: Boas-vindas (5 segundos + fade-out)
 * Fase 2: Opções (3 botões estilo Wibushi)
 * Fase 3: Progresso (Loading26 + status em tempo real via WebSocket)
 *
 * WebSocket conectado UMA VEZ no nível do App (não dentro de Progress)
 * para evitar conexões duplicadas no React StrictMode.
 */

import { useState, useCallback } from 'react';
import TitleBar from './components/TitleBar';
import Welcome from './components/Welcome';
import Options from './components/Options';
import Progress from './components/Progress';
import { useWebSocket } from './hooks/useWebSocket';

type Fase = 'boas-vindas' | 'opcoes' | 'progresso';

export default function App() {
  const [faseAtual, setFaseAtual] = useState<Fase>('boas-vindas');
  const [funcaoEscolhida, setFuncaoEscolhida] = useState<string>('');

  // WebSocket conectado UMA VEZ no nível do App — evita duplicação
  const ws = useWebSocket();

  // Callback: boas-vindas finalizada → mostra opções
  const aoFinalizarBoasVindas = useCallback(() => {
    setFaseAtual('opcoes');
  }, []);

  // Callback: opção escolhida → mostra progresso
  const aoEscolherOpcao = useCallback((funcao: string) => {
    setFuncaoEscolhida(funcao);
    setFaseAtual('progresso');
  }, []);

  return (
    <div id="janela-principal">
      {/* Barra de título personalizada — equivalente a criarBarraTitulo() */}
      <TitleBar />

      {/* Container principal com overlay */}
      <div className="conteudo-principal">
        {/* Container das fases */}
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
