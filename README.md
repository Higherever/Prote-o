# 🛡️ Proteção Completa — CachyOS (Gaming Safe)

O **Proteção** é uma solução robusta para endurecimento de segurança no CachyOS/Arch Linux, projetada para ser 100% compatível com jogos online (Steam, Epic, BattlEye, EAC) enquanto protege sua privacidade e integridade do sistema.

Esta nova versão conta com uma interface moderna em **Electron + React** e um backend potente em **Python (FastAPI)** que gerencia a execução segura do script de instalação.

---

## 🚀 O que o projeto faz?

O sistema atua em quatro frentes principais de forma automatizada:

| Camada | Funcionalidade | Gaming Safe? |
|:--- |:--- |:---:|
| **🌐 Cloudflare WARP** | Oculta seu IP real e criptografa o tráfego DNS. | ✅ Sim |
| **🛡️ nftables Firewall** | Firewall moderno com política DROP restritiva, pré-configurado para portas Steam/Blizzard/Epic. | ✅ Sim |
| **⚙️ Kernel Hardening** | Ajustes de sysctl para proteção contra ataques de memória e ptrace, sem quebrar Anti-Cheats. | ✅ Sim |
| **🚫 Fail2Ban** | Proteção ativa contra ataques de dicionário e brute-force em serviços locais. | ✅ Sim |

### 🎨 Interface Gráfica (GUI) v0.2.0
A interface foi totalmente remodelada para uma experiência **Premium** e **High-End**:

1.  **Welcome & Fade-out**: Transições suaves e introdução minimalista.
2.  **Premium Options**: Botões estilizados com animação de preenchimento dinâmico (estilo Wibushi).
3.  **Dark Mode Nativo**: Interface otimizada para o tema escuro (`#3c3b46`) para reduzir o cansaço visual.
4.  **Progresso em Tempo Real**: Acompanhamento via WebSocket com a nova animação `Loading26` e logs detalhados do backend.

---

## 🛠️ Tecnologias Utilizadas

O projeto utiliza uma stack moderna para garantir performance e facilidade de manutenção:

*   **Frontend**: [React 19](https://react.dev/) com [TypeScript](https://www.typescriptlang.org/) e [Vite](https://vitejs.dev/). Estilizado com CSS3 puro e animações Canvas.
*   **Desktop Shell**: [Electron 35](https://www.electronjs.org/) para uma experiência de aplicativo nativo.
*   **Backend**: [Python 3.14+](https://www.python.org/) com [FastAPI](https://fastapi.tiangolo.com/) e WebSockets para comunicação bidirecional.
*   **Script Core**: Bash especializado para Arch Linux / CachyOS com sistema de logs cumulativos.
*   **Segurança**: Integração com **PolicyKit (pkexec)** para elevação de privilégios segura.

---

## 📋 Pré-requisitos (CachyOS / Arch)

Para que o script e a interface funcionem perfeitamente no seu CachyOS, você deve garantir que possui as seguintes dependências instaladas:

```bash
# Instalar dependências básicas de compilação e execução
sudo pacman -S --needed base-devel git nodejs npm python python-pip python-virtualenv 

# Garantir que o Polkit está presente (geralmente já vem no CachyOS)
sudo pacman -S --needed polkit 
```

**Nota**: O projeto configura automaticamente um Ambiente Virtual (venv) para o Python e instala as dependências do Node.js durante o primeiro uso.

---

## 📥 Como Usar

> **Requisito**: tenha `git`, `nodejs`, `npm`, `python`, `python-virtualenv` e `polkit` instalados.
> ```bash
> sudo pacman -S --needed git nodejs npm python python-virtualenv polkit
> ```

Cole o bloco abaixo no terminal. Ele clona o repositório, instala todas as dependências e abre a interface visual automaticamente:

```bash
git clone https://github.com/Higherever/Prote-o.git && \
cd Prote-o/app && \
python3 -m venv backend/venv && \
backend/venv/bin/pip install -r backend/requirements.txt -q && \
npm install --silent && \
npm run build && \
electron .
```

> **O que cada passo faz:**
> 1. `git clone` — Baixa o repositório
> 2. `python3 -m venv` — Cria o ambiente virtual Python isolado
> 3. `pip install` — Instala FastAPI, Uvicorn e dependências do backend
> 4. `npm install` — Instala React, Electron e dependências do frontend
> 5. `npm run build` — Compila o React para produção
> 6. `electron .` — Abre a interface visual

---

## 📊 Sistema de Logs

O projeto mantém um histórico detalhado para facilitar a depuração:
*   **Logs da Interface**: Localizados em `logs/logFront/`
*   **Logs do Instalador**: Localizados em `logs/logBack/`

---

## 📞 Suporte e Comandos Úteis

Após a instalação, você pode gerenciar os serviços manualmente se desejar:
*   Status do WARP: `warp-cli status`
*   Regras de Firewall: `sudo nft list ruleset`
*   Status do Hardening: `sysctl kernel.yama.ptrace_scope`

---
*Desenvolvido para a comunidade CachyOS.* 🛡️🎮
