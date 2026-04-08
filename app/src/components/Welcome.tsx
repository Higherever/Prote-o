/**
 * Welcome — Fase 1 (Boas-Vindas)
 *
 * Apresentação inicial da animação "Bubble Closing". 
 * Após um timer, a bolha encolhe graciosamente via CSS e transiciona para a Fase 2 (Opções).
 */

import { useState, useEffect } from 'react';

interface WelcomeProps {
  onComplete: () => void;
}

export default function Welcome({ onComplete }: WelcomeProps) {
  const [faseAnimacao, setFaseAnimacao] = useState<'entrada' | 'fechando'>('entrada');

  useEffect(() => {
    // Inicia o fechamento da bolha após 2.5s de apresentação
    const timer = setTimeout(() => {
      setFaseAnimacao('fechando');
    }, 2500);

    return () => clearTimeout(timer);
  }, []);

  const handleAnimationEnd = (e: React.AnimationEvent) => {
    // Apenas transiciona para a próxima fase quando a animação específica 'bubbleClose' terminar
    if (faseAnimacao === 'fechando' && e.animationName === 'bubbleClose') {
      onComplete();
    }
  };

  return (
    <div className="tela-boas-vindas" id="tela-boas-vindas">
      <div 
        className={`bolha-wrapper ${faseAnimacao === 'fechando' ? 'bolha-fechando' : ''}`}
        onAnimationEnd={handleAnimationEnd}
      >
        <div className="boas-vindas-bolha">
          <div className={`bolha-conteudo ${faseAnimacao === 'fechando' ? 'conteudo-escondido' : ''}`}>
            <h1 className="texto-boas-vindas" style={{ fontSize: '38px', marginBottom: '12px' }}>Proteção</h1>
            <p className="subtexto-boas-vindas">Bem-vindo ao sistema de configuração</p>
          </div>
        </div>
      </div>
    </div>
  );
}
