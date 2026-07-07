#!/usr/bin/env bash
# Instala o second brain num projeto.
# Uso: ./install.sh /caminho/do/projeto
#  ou: cd /caminho/do/projeto && /caminho/do/claude-second-brain/install.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET="${1:-$PWD}"

if [ ! -d "$TARGET" ]; then
  echo "ERRO: diretório de destino não existe: $TARGET" >&2
  exit 1
fi

if [ "$(cd "$TARGET" && pwd)" = "$SCRIPT_DIR" ]; then
  echo "ERRO: o destino é o próprio repositório do tooling" >&2
  exit 1
fi

cd "$TARGET"

echo "Instalando o second brain em: $TARGET"
echo

# 1. Estrutura .claude/
mkdir -p .claude/hooks .claude/commands

# 2. Hook de abertura
cp "$SCRIPT_DIR/hooks/load-recent.sh" .claude/hooks/load-recent.sh
chmod +x .claude/hooks/load-recent.sh
echo "  ✓ .claude/hooks/load-recent.sh"

# 3. Slash commands
for cmd in save save-crisis resume write-task; do
  cp "$SCRIPT_DIR/commands/$cmd.md" ".claude/commands/$cmd.md"
  echo "  ✓ .claude/commands/$cmd.md"
done

# 3b. Check executável do /write-task
cp "$SCRIPT_DIR/write-task-check.sh" .claude/write-task-check.sh
chmod +x .claude/write-task-check.sh
echo "  ✓ .claude/write-task-check.sh"

# 4. settings.json: cria se não existe; senão avisa (não sobrescreve)
if [ ! -f .claude/settings.json ]; then
  cp "$SCRIPT_DIR/settings.template.json" .claude/settings.json
  echo "  ✓ .claude/settings.json (criado)"
else
  echo "  ⚠ .claude/settings.json já existe. Registre o hook manualmente"
  echo "    (bloco SessionStart de $SCRIPT_DIR/settings.template.json)"
fi

# 5. Diretório de diários
mkdir -p .claude-memory
echo "  ✓ .claude-memory/ (vazio)"

# 6. .gitignore
GITIGNORE=".gitignore"

# 6a. Detecta se .claude/ está sendo ignorado por algum gitignore externo
# (global, ~/.config/git/ignore, etc). Se sim, precisa adicionar exceção
# no .gitignore local, senão hooks/commands não vão pro git do projeto.
CLAUDE_IGNORED_EXTERNAL=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  # check-ignore retorna 0 se ignorado. Rodamos contra um caminho dentro
  # de .claude/ pra evitar falso negativo quando só o diretório é ignorado.
  if git check-ignore -q .claude/hooks/load-recent.sh 2>/dev/null; then
    CLAUDE_IGNORED_EXTERNAL=1
  fi
fi

# 6b. Monta bloco a adicionar (apenas o que ainda não está presente)
ADD_BLOCK=""
add_line() {
  local line="$1"
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$line" "$GITIGNORE"; then
    ADD_BLOCK+="$line"$'\n'
  fi
}

if [ "$CLAUDE_IGNORED_EXTERNAL" = "1" ]; then
  add_line "!.claude/"
  add_line "!.claude/**"
fi
add_line ".claude/settings.local.json"
add_line ".claude-memory/"

if [ -n "$ADD_BLOCK" ]; then
  {
    [ -f "$GITIGNORE" ] && echo
    echo "# Second brain (diários são locais, fora do git)"
    printf '%s' "$ADD_BLOCK"
  } >> "$GITIGNORE"
  if [ "$CLAUDE_IGNORED_EXTERNAL" = "1" ]; then
    echo "  ✓ .gitignore (exceção pra .claude/ + .claude-memory/)"
  else
    echo "  ✓ .gitignore (.claude-memory/ + settings.local.json)"
  fi
else
  echo "  ✓ .gitignore já configurado"
fi

echo
echo "Pronto. Próximos passos:"
echo "  1. git add .claude/ .gitignore && git commit -m 'chore: instala o second brain'"
echo "  2. Trabalhe normalmente e rode /save no fim da sessão pra gerar o diário"
