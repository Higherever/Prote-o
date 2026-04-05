#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Inicializando o Proteção              "
echo "========================================"

# Mudar para o diretório "app" a partir do diretório onde o script está
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/app"

# 1. Checa e Instala dependências do Python (Backend)
echo "➜ Checando dependências do motor invisível (Python)..."
if [ ! -d "backend/venv" ]; then
    echo "  >> Criando ambiente virtual Python (Isolado)..."
    python3 -m venv backend/venv
fi
backend/venv/bin/pip install -r backend/requirements.txt -q

# 2. Checa e Instala dependências do React/Electron (Frontend)
echo "➜ Checando dependências visuais (Node/Electron)..."
if [ ! -d "node_modules" ] || [ ! -d "dist" ]; then
    echo "  >> Baixando e configurando painéis visuais. Isso levará alguns segundos na primeira vez..."
    npm install --silent
    echo "  >> Empacotando gráficos visuais (Build)..."
    npm run build
fi

# 3. Execução Final
echo "➜ Decolagem Autorizada! Abrindo interface..."
npx electron .
