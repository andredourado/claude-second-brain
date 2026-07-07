---
description: Registra um problema descoberto como task acionável (causa-raiz + o que achei + como resolver + como testar), validada por check executável
---

Registra um problema que **fica pra depois** como uma **task acionável**, escrita agora, com o contexto vivo, pra uma sessão fria (ou eu daqui a 10 min) pegar pronta sem reinvestigar.

**Por que este comando existe**: o defeito recorrente é registrar *o problema* mas não *o que exatamente foi encontrado* nem *como resolver*. O molde abaixo não conserta isso sozinho (dá pra preencher raso), por isso o passo do **check executável é obrigatório** e é o que dá dente ao comando.

**Quando rodar:** no instante em que se decide que um problema não será resolvido nesta sessão. O usuário puxa o gatilho; eu posso sugerir "isso é candidato a `/write-task`" quando adio um conserto, mas quem decide é ele.

**Não confundir com `/save`:** `/save` é o log do que aconteceu na sessão. `/write-task` é uma *task de fazer*, durável e específica do tópico, que vive na memória semântica e volta sozinha pelo recall quando o assunto reaparece.

## Onde escrever

Na pasta de memória semântica do projeto, arquivo `task-<slug-curto>.md`, no formato nativo do Claude Code:

```
---
name: task-<slug-curto>
description: <uma linha: o que está quebrado e onde, pra o recall achar>
metadata:
  type: project
---
```

Seguido das **5 seções, com estes títulos exatos** (o check depende deles):

- `## Causa-raiz`: nomeada pelo **comportamento do sistema**, não pelo sintoma.
- `## O que achei`: as evidências concretas **desta sessão**: arquivo/linha, símbolo, o mecanismo verificado, o que foi reproduzido. Cite arquivos/símbolos entre `backticks`. É a parte que costuma sumir.
- `## Como resolver`: passos concretos e **onde** (arquivo/função entre `backticks`), não "investigar X". Se ainda não se sabe onde, a task não está pronta: descubra antes de registrar.
- `## Como testar`: como saber que acabou: comando a rodar, critério de aceite observável.
- Linha final `**Estado:** aberta` (vira `fechada` quando resolvida).

Depois adicione **um ponteiro de uma linha** no índice `MEMORY.md` da mesma pasta.

**Regra anti-alucinação (inviolável, a mesma do `/save`):** citar conteúdo de arquivo/código/schema exige **ler com `Read` antes**. Referências `arquivo:linha` só com o que foi de fato lido nesta sessão.

## Validação obrigatória (o check)

Depois de escrever o arquivo e o ponteiro, **rode o check e só dê a task por pronta se ele sair 0**:

```
bash .claude/write-task-check.sh <caminho-completo-do-task-.md>
```

Se sair `FALHA`, **corrija cada item listado e rode de novo**. Não relate a task como criada enquanto o check não passar. Mostre a saída do check ao usuário.

## Fechar uma task

**O fechamento é reconciliado pelo `/save`**, não é um ritual à parte: no fim da sessão que resolveu o problema, o `/save` varre as tasks deste projeto, fecha as que a sessão de fato resolveu e grava o `Desfecho`. Pode-se fechar na mão no meio da sessão; o `/save` só confere.

Ao fechar, **não apague o arquivo**: `**Estado:** fechada`, uma linha de como foi resolvido (commit/arquivo), e o ponteiro continua no índice (task fechada vira histórico consultável pelo recall).

**Ao fechar, declare o desfecho** (linha obrigatória; o check exige em task fechada):

```
**Desfecho:** pela-task | reinvestiguei | obsoleta
```

- `pela-task`: a sessão que resolveu **usou** o `## Como resolver`/`## O que achei` da task e bateu. A captura fez o trabalho. É o único caso que conta como sucesso.
- `reinvestiguei`: resolvi, mas a task **não bastou**; foi preciso reabrir a investigação (causa-raiz errada ou registro raso). É o sinal mais valioso: a captura precisa melhorar.
- `obsoleta`: deixou de importar sem ser resolvida. Neutro, fora da taxa.

**Regra do default pessimista:** na dúvida entre `pela-task` e `reinvestiguei`, marque `reinvestiguei`. A taxa só tem valor se for pessimista por construção; inflar o placar mata o sinal.

## Ao final

1. Mostre o caminho do `task-*.md`, a linha adicionada ao índice, e a saída do check.
2. Memória semântica não é versionada. Não commitar nada por causa da task.
