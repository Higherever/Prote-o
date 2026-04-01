# CHANGELOG

Todos os mudanças notáveis neste projeto são documentadas neste arquivo.

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
- Para compilar a GUI: `cd gui && CGO_CFLAGS="-w" go build -o protecao-gui .`
