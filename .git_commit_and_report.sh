#!/usr/bin/env bash
set -euo pipefail

# Script para adicionar/commitar alterações e imprimir hash + arquivos alterados
cd '/home/gambeta/Documentos/Script Linux/Prote-o'

git add -A

if git diff --cached --quiet; then
  echo "NO_COMMIT"
  exit 0
fi

git -c user.name='Lelo (IA)' -c user.email='lelo@local.invalid' commit -m 'feat(instalar.sh): add logging system and MEMORI_PROMPT entry'

HASH=$(git rev-parse --short HEAD)
echo "COMMIT_OK:$HASH"
echo "FILES_CHANGED:"
git show --name-only --pretty=format:'' HEAD

echo "TIMESTAMP:$(date '+%Y-%m-%d %H:%M:%S')"
