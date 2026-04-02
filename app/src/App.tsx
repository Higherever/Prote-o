/**
 * App.tsx — Equivalente ao gui/ui/window.go
 *
 * Gerencia o layout principal e as 3 fases da aplicação:
 * Fase 1: Boas-vindas (5 segundos + fade-out)
 * Fase 2: Opções (3 botões)
 * Fase 3: Progresso (GIF + status em tempo real)
 *
 * O fundo com vagalumes é renderizado permanentemente atrás de tudo.
 *
 * CORREÇÃO: WebSocket conectado UMA VEZ no nível do App (não dentro de Progress)
 * para evitar conexões duplicadas no React StrictMode.
 */

import { useState, useCallback } from 'react';
import TitleBar from './components/TitleBar';
import Welcome from './components/Welcome';
import Options from './components/Options';
import Progress from './components/Progress';
import Fireflies from './components/Fireflies';
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
        {/* Vagalumes no fundo — equivalente a NovoMotorVagalumes() */}
        <Fireflies quantidade={40} />

        {/* Container das fases (por cima dos vagalumes) */}
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
