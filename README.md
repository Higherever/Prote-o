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

### 🎨 Interface Gráfica (GUI) v2.0.0
A interface foi totalmente remodelada para uma experiência **Premium** e **High-End**:

1.  **Welcome & Fade-out**: Transições suaves e introdução minimalista.
2.  **Premium Options**: Botões estilizados com animação de preenchimento dinâmico (estilo Wibushi).
3.  **Dark Mode Nativo**: Interface otimizada para o tema escuro (`#3c3b46`) para reduzir o cansaço visual.
4.  **Progresso em Tempo Real**: Acompanhamento via WebSocket com a nova animação `Loading26` (SVG Jelly Ooze) e logs detalhados do backend.
5.  **Performance Otimizada**: Removidas dependências pesadas (`cobe`, `motion`) para garantir um carregamento instantâneo.

---

## 🛠️ Tecnologias Utilizadas

O projeto utiliza uma stack moderna para garantir performance e facilidade de manutenção:

*   **Frontend**: [React 19](https://react.dev/) com [TypeScript](https://www.typescriptlang.org/) e [Vite](https://vitejs.dev/).
*   **Desktop Shell**: [Electron 35](https://www.electronjs.org/) para uma experiência de aplicativo nativo.
*   **Backend**: [Python 3.14+](https://www.python.org/) com [FastAPI](https://fastapi.tiangolo.com/) e WebSockets para comunicação bidirecional.
*   **Script Core**: Bash especializado para Arch Linux / CachyOS com sistema de logs cumulativos.
*   **Segurança**: Integração com **PolicyKit (pkexec)** para elevação de privilégios segura.

---

## 📋 Pré-requisitos (CachyOS / Arch)

Certifique-se de possuir as ferramentas básicas instaladas:

```bash
# Instalar dependências essenciais
sudo pacman -S --needed base-devel git nodejs npm python python-pip python-virtualenv polkit
```

---

## 📥 Como Usar (Passo a Passo)

Siga os comandos abaixo um de cada vez ou cole o bloco completo no seu terminal:

### 1. Clonar e Acessar
```bash
git clone https://github.com/Higherever/Prote-o.git && cd Prote-o/app
```

### 2. Configurar Ambiente Python (Backend)
```bash
python3 -m venv backend/venv && \
backend/venv/bin/pip install -r backend/requirements.txt -q
```

### 3. Instalar e Compilar Frontend (React + Electron)
```bash
npm install --silent && npm run build
```

### 4. Executar a Proteção
```bash
electron .
```

> **Dica**: Após a primeira instalação, você só precisará executar `electron .` dentro da pasta `app/` para abrir o programa.

---

## 📊 Sistema de Logs

O projeto mantém um histórico detalhado para facilitar a depuração:
*   **Logs da Interface (Frontend)**: Localizados em `logs/logFront/` (mantém os últimos 10 logs).
*   **Logs do Instalador (Script)**: Localizados em `logs/logBack/` (logs detalhados de cada execução).

---

## 📞 Suporte e Comandos Úteis

Se você precisar gerenciar os serviços manualmente:
*   Status do WARP: `warp-cli status`
*   Regras de Firewall: `sudo nft list ruleset`
*   Status do Hardening: `sysctl kernel.yama.ptrace_scope`

---
*Desenvolvido com foco em performance e segurança para a comunidade CachyOS.* 🛡️🎮
