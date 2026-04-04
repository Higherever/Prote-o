# CHANGELOG

Todos os mudanças notáveis neste projeto são documentadas neste arquivo.

## [v0.2.0] - 2026-04-02

### Added
- Tema Escuro (Dark Mode) configurado como padrão (`#3c3b46` e `#f7f7f7`).
- Novo componente de animação `Loading26.tsx` para a tela de progresso.
- Sistema de retenção de logs: limite de 10 arquivos por categoria com limpeza automática do mais antigo.
- Coleta automática de metadados do sistema (Kernel, OS, Display Server, Desktop Environment) nos logs.
- Estilização premium dos botões de opções com animação de preenchimento lateral (estilo Wibushi).

### Removed
- `app/src/components/Fireflies.tsx`: Removido em favor do novo tema visual simplificado.

## [v0.1.5] - 2026-04-02

### Added
- Migração completa da interface gráfica de Go (GTK3) para Python (FastAPI) + React (Vite+TS) + Electron.
- Sistema de logs cumulativos em `logs/logFront/` e `logs/logBack/`.
- Nova animação centralizada (`Loop.gif`) com tema claro e visual moderno.
- Suporte a ambiente virtual (venv) para isolamento de dependências Python.
- Tratamento de códigos ANSI nos logs capturados do script.
- Verificação visual de redimensionamento dinâmico (responsividade no Hyprland).

### Changed
- `instalar.sh`: Adicionada flag `--accept-tos` para o `warp-cli`, permitindo execução não interativa via pkexec.
- `instalar.sh`: Ajuste de permissões de log para 644 após execução via root.
- Removido diretório legado `gui/` (Go).

### Fixed
- Erro de aceitação de termos do Cloudflare WARP sem TTY.
- Problema de conexões WebSocket duplicadas no React StrictMode.
- Erro de tipos TypeScript na API do Electron e caminhos de módulos.
- Tela branca no modo produção do Electron.

## [v0.1.3] - 2026-03-31

### Added
- Adição da interface gráfica em Go (GTK3 via gotk3).
- Integração com Polkit (D-Bus) para autenticação.
- Runner para executar funções do instalar.sh via pkexec com a variável PROTECAO_RUN_FUNC.
- Telas: Boas-vindas, Opções, Progresso; animação de vagalumes; suporte a loading.webm (fallback para emoji).
- Parser robusto para respostas do CheckAuthorization do Polkit.
- Atualização do MEMORI_PROMPT.md com detalhamento das correções e testes.

### Notes
- Requer `pkexec` e um agente gráfico Polkit ativo (ex.: polkit-gnome-authentication-agent-1).
- **Nota:** Esta versão em Go (GTK3) foi substituída pela stack Python+React+Electron na v0.1.5.
