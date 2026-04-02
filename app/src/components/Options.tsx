/**
 * Options — Equivalente ao gui/ui/options.go
 *
 * Tela de opções (Fase 2):
 * - 3 botões estilizados com fade-in
 * - Ao clicar: desabilita botões, faz POST ao backend Python
 * - Backend executa pkexec (que aciona Polkit) e roda o instalar.sh
 * - Após iniciar execução, notifica o App para transição para Progresso
 *
 * As opções são as mesmas do options.go:
 * - Opção 1: instalar_seguranca
 * - Opção 2: instalar_jogos
 * - Opção 3: configuracao_completa
 */

import { useState } from 'react';

const API_BASE = 'http://127.0.0.1:8000';

// Definição das opções — equivalente a var Opcoes em options.go
const OPCOES = [
  { nome: 'Opção 1 — Segurança', funcao: 'instalar_seguranca' },
  { nome: 'Opção 2 — Jogos', funcao: 'instalar_jogos' },
  { nome: 'Opção 3 — Configuração Completa', funcao: 'configuracao_completa' },
];

interface OptionsProps {
  onSelect: (funcao: string) => void;
}

export default function Options({ onSelect }: OptionsProps) {
  const [desabilitado, setDesabilitado] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Ao clicar em um botão — equivalente a aoClicar()
  const handleClick = async (funcao: string) => {
    console.log(`[UI] Usuário clicou para iniciar a função: ${funcao}`);
    setDesabilitado(true);
    setErro(null);

    try {
      // POST ao backend para iniciar a execução
      // O backend cuida do pkexec (Polkit) e execução do script
      const response = await fetch(`${API_BASE}/api/executar`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ funcao }),
      });

      const data = await response.json();

      if (data.status === 'ok') {
        console.log(`[UI] Execução de ${funcao} iniciada com sucesso`);
        // Transição para tela de progresso
        onSelect(funcao);
      } else {
        console.error(`[UI] Erro: ${data.mensagem}`);
        setErro(data.mensagem);
        setDesabilitado(false);
      }
    } catch (err) {
      console.error('[UI] Falha na comunicação com o backend:', err);
      setErro('Falha na comunicação com o backend. Verifique se o servidor está rodando.');
      setDesabilitado(false);
    }
  };

  return (
    <div className="tela-opcoes" id="tela-opcoes">
      <h2 className="titulo-opcoes">Escolha uma opção</h2>

      {OPCOES.map((opcao, index) => (
        <button
          key={opcao.funcao}
          className="btn-opcao"
          disabled={desabilitado}
          onClick={() => handleClick(opcao.funcao)}
          id={`btn-opcao-${index + 1}`}
          style={{ animationDelay: `${index * 100}ms` }}
        >
          {opcao.nome}
        </button>
      ))}

      {erro && (
        <p style={{ color: 'var(--color-error)', fontSize: '13px', marginTop: '8px' }}>
          {erro}
        </p>
      )}
    </div>
  );
}
