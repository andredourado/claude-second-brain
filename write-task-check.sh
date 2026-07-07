#!/usr/bin/env bash
# write-task-check.sh: valida que uma task escrita pelo /write-task está
# ACIONÁVEL (não rasa) antes de ser dada como pronta.
#
# Por que existe: o ganho do /write-task não é o molde de 5 campos, é ESTE
# check. Um molde o modelo preenche raso ("como resolver: investigar o
# worker") e marca como feito; o check falha sem intervenção humana e barra
# task anunciada-mas-não-escrita.
#
# Uso: write-task-check.sh /caminho/para/task-<slug>.md
# Sai 0 se passa; !=0 listando cada falha concreta a corrigir.

set -uo pipefail

F="${1:-}"
[ -z "$F" ] && { echo "uso: $0 <arquivo-da-task>" >&2; exit 2; }
[ -f "$F" ] || { echo "FALHA: arquivo não existe: $F" >&2; exit 2; }

fails=()

# 1. Frontmatter nativo (name / description / metadata.type)
grep -qE '^name:'        "$F" || fails+=("frontmatter sem 'name:'")
grep -qE '^description:'  "$F" || fails+=("frontmatter sem 'description:'")
grep -qE '^[[:space:]]*type:[[:space:]]*(project|reference|feedback|user)' "$F" \
  || fails+=("frontmatter sem 'metadata.type' válido")

# Extrai o corpo de uma seção '## <titulo>' até o próximo '## ' ou EOF.
section() {
  awk -v h="## $1" '
    $0==h        {grab=1; next}
    /^## /       {grab=0}
    grab         {print}
  ' "$F"
}
nonblank() { [ -n "$(tr -d '[:space:]' <<<"$1")" ]; }
has_code_ref() { grep -q '`[^`]\+`' <<<"$1"; }  # ao menos um `trecho` citando arquivo/símbolo

# 2. Causa-raiz: presente e não-vazia
nonblank "$(section 'Causa-raiz')" || fails+=("seção '## Causa-raiz' ausente ou vazia")

# 3. O que achei: não-vazia E cita arquivo/símbolo concreto entre backticks
oqa="$(section 'O que achei')"
if ! nonblank "$oqa"; then
  fails+=("seção '## O que achei' ausente ou vazia")
elif ! has_code_ref "$oqa"; then
  fails+=("'## O que achei' não cita arquivo/símbolo entre backticks (faltou evidência concreta)")
fi

# 4. Como resolver: não-vazia E aponta ONDE corrigir entre backticks
cmr="$(section 'Como resolver')"
if ! nonblank "$cmr"; then
  fails+=("seção '## Como resolver' ausente ou vazia")
elif ! has_code_ref "$cmr"; then
  fails+=("'## Como resolver' não aponta onde (arquivo/função) entre backticks; verbo vago não conta")
fi

# 5. Como testar / critério de aceite
nonblank "$(section 'Como testar')" || fails+=("seção '## Como testar' ausente ou vazia")

# 6. Estado: enum de UMA palavra logo após 'Estado:'. 'resolvida'/'concluída'
# são apelidos de fechada (vocabulário natural em PT, validado pelo uso real).
# Prosa de status colada NÃO casa, de propósito: o campo é enum pra máquina
# ler; a história vai pro corpo / Desfecho.
grep -qiE '^[*]{0,2}Estado:?[*]{0,2}[[:space:]]*(aberta|fechada|resolvida|conclu)' "$F" \
  || fails+=("linha 'Estado:' ausente ou não começa com aberta|fechada|resolvida|concluída (não use prosa de status aqui)")

# 6b. Desfecho: obrigatório SÓ em task fechada/resolvida/concluída (é o que
# torna o sucesso mensurável). Task aberta não exige.
if grep -qiE '^[*]{0,2}Estado:?[*]{0,2}[[:space:]]*(fechada|resolvida|conclu)' "$F"; then
  grep -qiE '^[*]{0,2}Desfecho:?[*]{0,2}[[:space:]]*(pela-task|reinvestiguei|obsoleta|retroativo)' "$F" \
    || fails+=("task fechada sem 'Desfecho: pela-task|reinvestiguei|obsoleta|retroativo' (sucesso não-mensurável)")
fi

# 7. Ponteiro de uma linha no MEMORY.md da mesma pasta
dir="$(dirname "$F")"
slug="$(basename "$F" .md)"
if [ -f "$dir/MEMORY.md" ]; then
  grep -q "$slug" "$dir/MEMORY.md" || fails+=("ponteiro pra '$slug' ausente no MEMORY.md")
else
  fails+=("MEMORY.md não encontrado em $dir")
fi

if [ ${#fails[@]} -eq 0 ]; then
  echo "OK: task acionável: $(basename "$F")"
  exit 0
fi
echo "FALHA: task rasa. Corrija e rode de novo:" >&2
for f in "${fails[@]}"; do echo "  - $f" >&2; done
exit 1
