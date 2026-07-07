#!/usr/bin/env bash
# Second brain: carrega o contexto recente pro Claude Code na abertura.
#
# Comportamento:
#   - Se existir .claude-memory/_resume.md (gerado pelo /save), mostra só ele:
#     a síntese de 5 bullets do estado atual do projeto.
#   - Se não existir (projeto recém-instalado), mostra os diários crus
#     das últimas horas como fallback.
#
# Configuração via variável de ambiente:
#   CLAUDE_MEMORY_WINDOW_HOURS  janela do fallback em horas (default: 48)

set -euo pipefail

MEM_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude-memory"
WINDOW_HOURS="${CLAUDE_MEMORY_WINDOW_HOURS:-48}"

[ ! -d "$MEM_DIR" ] && exit 0

PROJECT_NAME=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")
RESUME_FILE="$MEM_DIR/_resume.md"

if [ -f "$RESUME_FILE" ]; then
  echo "## Resume: projeto $PROJECT_NAME"
  echo
  cat "$RESUME_FILE"
  exit 0
fi

WINDOW_MIN=$(( WINDOW_HOURS * 60 ))
files=$(find "$MEM_DIR" -maxdepth 1 -name "*.md" ! -name "_*.md" -mmin -"$WINDOW_MIN" -type f 2>/dev/null | sort)

[ -z "$files" ] && exit 0

echo "## Diário recente: projeto $PROJECT_NAME (últimas ${WINDOW_HOURS}h)"
echo

while IFS= read -r f; do
  echo "### $(basename "$f" .md)"
  cat "$f"
  echo
done <<< "$files"
