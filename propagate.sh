#!/usr/bin/env bash
# Propaga o tooling (hook + commands + check) pra todos os projetos adotantes.
#
# Adotante = qualquer diretório dentro de PROJECTS_DIR com
# .claude/commands/save.md. Pra cada um: copia os arquivos canônicos que
# mudaram e, salvo --no-commit, commita+pusha só esses arquivos, por nome.
# Repos locais sem remote `origin` commitam mas não pusham.
#
# install.sh é one-shot; este script resolve o update de quem já adotou.
# A lista de adotantes é descoberta por varredura, não hardcoded.
#
# Configuração:
#   PROJECTS_DIR  diretório que contém os projetos
#                 (default: o diretório pai deste repositório)
#
# Uso:
#   ./propagate.sh             # copia + commit + push em todos
#   ./propagate.sh --dry-run   # mostra o que faria, sem tocar em nada
#   ./propagate.sh --no-commit # só copia (não commita nem pusha)

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECTS_DIR="${PROJECTS_DIR:-$(dirname "$SCRIPT_DIR")}"

DRY_RUN=0
DO_COMMIT=1
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --no-commit) DO_COMMIT=0 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $arg (use --dry-run | --no-commit | --help)" >&2; exit 2 ;;
  esac
done

# Arquivos canônicos: "origem_relativa_ao_repo|destino_relativo_ao_projeto".
# settings.json fica de fora de propósito: é install-only, customizável por projeto.
FILES=(
  "hooks/load-recent.sh|.claude/hooks/load-recent.sh"
  "commands/save.md|.claude/commands/save.md"
  "commands/save-crisis.md|.claude/commands/save-crisis.md"
  "commands/resume.md|.claude/commands/resume.md"
  "commands/write-task.md|.claude/commands/write-task.md"
  "write-task-check.sh|.claude/write-task-check.sh"
)

SRC_SHA=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")
COMMIT_MSG="chore: atualiza tooling do second brain (@$SRC_SHA)

Propagado por propagate.sh."

# Descobre adotantes por varredura (não hardcoded).
mapfile -t ADOPTERS < <(
  for d in "$PROJECTS_DIR"/*/; do
    [ -f "${d}.claude/commands/save.md" ] || continue
    [ "$(cd "$d" && pwd)" = "$SCRIPT_DIR" ] && continue   # o próprio repo do tooling
    echo "$d"
  done
)

echo "Fonte: $SCRIPT_DIR (@$SRC_SHA)"
echo "Varrendo: $PROJECTS_DIR"
echo "Adotantes encontrados: ${#ADOPTERS[@]}"
[ "$DRY_RUN" = 1 ] && echo "(dry-run: nada será alterado)"
[ "$DO_COMMIT" = 0 ] && echo "(--no-commit: só copia)"
echo

declare -a R_SYNC=() R_PUSH=() R_COMMIT_ONLY=() R_NOOP=() R_SKIP=()

for d in "${ADOPTERS[@]}"; do
  p=$(basename "$d")
  changed=()
  for pair in "${FILES[@]}"; do
    src="$SCRIPT_DIR/${pair%%|*}"
    rel="${pair##*|}"
    dst="${d}${rel}"
    [ -f "$src" ] || { echo "  ! origem ausente: $src"; continue; }
    [ -L "$dst" ] && continue                       # nunca escrever através de symlink
    [ -f "$dst" ] && cmp -s "$src" "$dst" && continue
    changed+=("$rel")
    if [ "$DRY_RUN" = 0 ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
  done

  if [ ${#changed[@]} -eq 0 ]; then
    printf "%-22s idêntico\n" "$p"; R_NOOP+=("$p"); continue
  fi

  printf "%-22s atualizado: %s\n" "$p" "${changed[*]}"
  [ "$DRY_RUN" = 1 ] && continue
  R_SYNC+=("$p")
  [ "$DO_COMMIT" = 0 ] && continue

  if ! git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "    (não é repo git: só copiado)"; R_SKIP+=("$p:nogit"); continue
  fi

  to_add=()
  for f in "${changed[@]}"; do
    if git -C "$d" check-ignore -q "$f"; then
      echo "    ($f gitignored: não commita)"; continue
    fi
    to_add+=("$f")
  done
  if [ ${#to_add[@]} -eq 0 ]; then R_SKIP+=("$p:ignored"); continue; fi

  git -C "$d" add "${to_add[@]}"
  # commit com pathspec: só esses arquivos, mesmo se houver outra coisa staged
  if ! git -C "$d" commit -q -m "$COMMIT_MSG" -- "${to_add[@]}" 2>/dev/null; then
    echo "    (commit falhou)"; R_SKIP+=("$p:commitfail"); continue
  fi
  br=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  if git -C "$d" push -q origin "$br" 2>/dev/null; then
    echo "    commit+push em $br"; R_PUSH+=("$p")
  else
    echo "    commit OK; push falhou (sem remote origin?) em $br"; R_COMMIT_ONLY+=("$p")
  fi
done

echo
echo "== Resumo =="
echo "Sincronizados: ${#R_SYNC[@]}  |  push OK: ${#R_PUSH[@]}  |  commit-only (sem remote): ${#R_COMMIT_ONLY[@]}  |  idênticos: ${#R_NOOP[@]}"
[ ${#R_COMMIT_ONLY[@]} -gt 0 ] && echo "Sem push (commit local feito): ${R_COMMIT_ONLY[*]}"
[ ${#R_SKIP[@]} -gt 0 ] && echo "Pulados: ${R_SKIP[*]}"
exit 0
