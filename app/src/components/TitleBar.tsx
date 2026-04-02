/**
 * TitleBar — Equivalente a criarBarraTitulo() em window.go
 *
 * Barra de título personalizada com:
 * - Título "Proteção" à esquerda
 * - Botões Minimizar, Maximizar, Fechar à direita
 * - Suporte a arrastar a janela (via -webkit-app-region: drag no CSS)
 * - Controle de janela via API do Electron (preload.js)
 */

export default function TitleBar() {
  const handleMinimize = () => {
    window.electronAPI?.minimizeWindow();
  };

  const handleMaximize = () => {
    window.electronAPI?.maximizeWindow();
  };

  const handleClose = () => {
    window.electronAPI?.closeWindow();
  };

  return (
    <div className="barra-titulo" id="barra-titulo">
      {/* Título da aplicação — equivalente ao Label "Proteção" */}
      <span className="titulo-app">Proteção</span>

      {/* Botões de controle — equivalente a boxBotoes */}
      <div className="botoes-titulo">
        <button
          className="btn-titulo"
          onClick={handleMinimize}
          title="Minimizar"
          id="btn-minimizar"
        >
          —
        </button>
        <button
          className="btn-titulo"
          onClick={handleMaximize}
          title="Maximizar"
          id="btn-maximizar"
        >
          □
        </button>
        <button
          className="btn-titulo btn-fechar"
          onClick={handleClose}
          title="Fechar"
          id="btn-fechar"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
