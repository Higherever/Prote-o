/**
 * Welcome — Equivalente ao gui/ui/welcome.go
 *
 * Tela de boas-vindas (Fase 1):
 * - Exibe "Bem-vindo ao Proteção" por 5 segundos
 * - Fade-out suave via CSS animation
 * - Ao terminar, chama onComplete para transição para Opções
 *
 * Configurações originais portadas:
 * - MensagemBoasVindas = "Bem-vindo ao Proteção"
 * - DuracaoBoasVindas = 5000ms
 * - PassosFadeOut = 20 (equivalente à animação CSS de ~600ms)
 */

import { useState, useEffect } from 'react';

interface WelcomeProps {
  onComplete: () => void;
}

// Constantes — mesmas do welcome.go
const MENSAGEM_BOAS_VINDAS = 'Bem-vindo ao Proteção';
const DURACAO_BOAS_VINDAS = 5000; // 5 segundos

export default function Welcome({ onComplete }: WelcomeProps) {
  const [saindo, setSaindo] = useState(false);

  useEffect(() => {
    // Após 5 segundos, inicia o fade-out — equivalente a glib.TimeoutAdd
    const timer = setTimeout(() => {
      setSaindo(true);
    }, DURACAO_BOAS_VINDAS);

    return () => clearTimeout(timer);
  }, []);

  // Quando a animação de fade-out termina, chama o callback
  const handleAnimationEnd = () => {
    if (saindo) {
      onComplete();
    }
  };

  return (
    <div
      className={`tela-boas-vindas ${saindo ? 'saindo' : ''}`}
      onAnimationEnd={handleAnimationEnd}
      id="tela-boas-vindas"
    >
      <h1 className="texto-boas-vindas">{MENSAGEM_BOAS_VINDAS}</h1>
      <p className="subtexto-boas-vindas">
        Configuração e proteção para CachyOS
      </p>
    </div>
  );
}
