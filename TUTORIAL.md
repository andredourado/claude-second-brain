# Second brain pro Claude Code: memória persistente entre sessões

## O problema

O Claude Code não lembra de nada entre sessões. Na segunda-feira você passa uma hora decidindo com ele que a fila de jobs vai usar polling em vez de webhook, e por quê. Na quinta, numa sessão nova, ele sugere webhook de novo, com toda a confiança do mundo. Cada sessão começa do zero: as decisões, os becos sem saída já explorados, as pendências e o "porquê" de cada escolha evaporam quando a janela fecha.

Este tutorial mostra como montar um "second brain" (um segundo cérebro): um sistema de memória persistente entre sessões, feito só de **arquivos markdown, bash e git**. Sem banco de dados, sem servidor, sem serviço externo, sem framework pra instalar. Uso esse sistema em produção em quase 20 projetos reais há meses.

O resultado prático: toda sessão nova do Claude Code abre já sabendo onde o projeto parou, o que foi decidido, o que está pendente e qual o próximo passo. Sem você digitar uma linha de contexto.

Todos os arquivos estão neste repositório e também colados inline no texto, na ordem em que você precisa deles.

---

## Parte 1: o que você ganha

**1. Fim do cold start.** Toda sessão nova abre com um resumo de 5 bullets injetado automaticamente: onde o projeto está, quais regras não podem ser violadas, o que as últimas sessões fizeram, o que está sendo avaliado e qual o próximo passo. Você não re-explica nada; o Claude não re-deduz nada.

**2. Cada informação guardada no lugar com o custo certo.** Tudo que o Claude "sabe" numa sessão ocupa espaço na janela de contexto e compete pela atenção do modelo com a sua tarefa. Um sistema de memória ingênuo despeja tudo no contexto e piora o agente em vez de melhorar. Este sistema separa a memória em 3 camadas com custos diferentes (regra que vale sempre / fato de um tópico específico / registro do dia a dia), e cada camada só é carregada quando faz sentido. A Parte 2 explica as camadas em detalhe; é o conceito central do sistema.

**3. O arquivo de instruções para de crescer sem controle.** O `CLAUDE.md` (arquivo de instruções que o Claude Code carrega inteiro em toda sessão) tende a virar depósito: cada sessão acrescenta "uma linhinha" e ninguém nunca remove nada. Um dos meus projetos chegou a 561 linhas assim, e cada sessão pagava o custo de ler tudo aquilo, relevante ou não. Aqui, o comando de fim de sessão (`/save`) faz curadoria ativa: avalia o que entra, o que deveria descer pra uma camada mais barata e o que apodreceu e deve sair.

**4. Problema adiado não vira investigação perdida.** Quando você descobre um bug mas decide resolver depois, o padrão de falha é anotar o sintoma ("export de CSV estoura timeout") e perder a investigação (qual arquivo, qual linha, o que já foi testado). Semanas depois, alguém reinvestiga tudo de novo. O comando `/write-task` registra o problema com a investigação completa, e um script de validação **recusa** registros rasos: sem evidência concreta e sem apontar onde corrigir, a task não é aceita.

**5. Você mede se a memória funciona de verdade.** Cada task fechada declara se a anotação resolveu o problema sozinha ou se foi preciso reinvestigar. Isso produz uma taxa de sucesso honesta do próprio sistema de memória, com viés pessimista de propósito (na dúvida, conta como falha). Sem isso, todo sistema de anotações "parece" estar funcionando.

**6. Incidente não perde urgência entre sessões.** Existe um padrão perigoso de LLM: entre uma sessão e outra, "23 vulnerabilidades críticas em aberto" vira "backlog de melhorias". O comando `/save-crisis` grava um banner de emergência no resumo da próxima sessão e proíbe explicitamente esse tipo de suavização.

**7. A memória não alucina.** Regra inviolável embutida nos comandos: pra citar o conteúdo de qualquer arquivo, o Claude precisa ler o arquivo naquele momento, nunca deduzir pelo nome. E pendências antigas são re-verificadas contra o estado atual do código antes de entrar no resumo (o diário pode conter um erro registrado; o resumo não pode).

**8. Instalação em um comando por projeto.** O sistema é uma pasta de arquivos copiáveis. Um script de bootstrap instala tudo num projeto novo; outro propaga atualizações pra todos os projetos que já adotaram.

**9. Zero infraestrutura, zero aprisionamento.** É tudo markdown legível e bash curto. Se você abandonar o sistema amanhã, os arquivos continuam úteis pra ler com qualquer editor.

---

## Parte 2: os 3 conceitos que sustentam o sistema

Antes do passo a passo, três ideias. Se você entender esta parte, o resto é só copiar arquivo.

### Conceito 1: contexto é um recurso caro

O Claude só "sabe" o que está na janela de contexto da sessão atual. Tudo que você injeta ali (instruções, memória, resumos) ocupa tokens e divide a atenção do modelo com a tarefa real. Ou seja: **memória demais piora o agente**. A pergunta de design de um sistema de memória não é "onde guardo tudo?", é "**o que carrego, e quando?**".

### Conceito 2: três camadas, três custos

O sistema guarda cada informação em uma de três camadas, escolhida pelo padrão de uso:

**Camada 1: o contrato (`CLAUDE.md`).** O Claude Code carrega esse arquivo inteiro, automaticamente, no início de **toda** sessão. É o lugar das regras que valem sempre, independente do que você está fazendo: "nunca faça force push", "responda sempre em português", "todo endpoint novo exige teste". É a camada mais cara: cada linha é lida em toda sessão, relevante ou não. Por isso ela precisa ficar enxuta.

**Camada 2: a memória semântica (pasta `memory/`).** O Claude Code tem memória nativa por projeto: uma pasta de arquivos markdown (um fato por arquivo, com um índice `MEMORY.md`) que ele **injeta automaticamente no contexto só quando o assunto aparece na conversa**. É o lugar dos fatos duráveis que só importam num tópico específico: "o deploy do serviço X é `scp` + `ssh restart`", "o campo `status` dessa tabela tem 3 valores legados, cuidado", "a API do fornecedor Y limita a 100 req/min". Custo baixo: se a sessão não toca no assunto, o fato não gasta um token.

**Camada 3: a memória temporal (pasta `.claude-memory/`).** Diários por dia de trabalho: o que foi feito, decidido, quebrado e adiado **em cada sessão**. Eventos com data, não regras. Essa camada quase não é carregada: ela existe pra alimentar um arquivo-síntese de 5 bullets (`_resume.md`) que é a única coisa injetada na abertura da sessão seguinte. Os diários ficam fora do git, só na sua máquina.

### Conceito 3: a regra de fronteira (onde guardar cada fato)

Na hora de guardar qualquer informação, uma única pergunta decide a camada:

> **"Esse fato precisa estar no contexto em TODA sessão, ou só quando o assunto dele aparecer?"**

| Exemplo de fato | Camada | Por quê |
|---|---|---|
| "Nunca rodar migration em produção sem backup" | Contrato (`CLAUDE.md`) | Vale em qualquer tarefa, sempre |
| "O deploy do worker é `scp` pro host X + restart do systemd" | Memória semântica | Só importa quando alguém mexe no deploy |
| "Hoje refatorei o parser e descobri que o campo `date` vem em 2 formatos" | Diário | Evento datado; o fato durável (os 2 formatos) pode ser promovido pra memória semântica |

Errar o destino tem custos assimétricos: mandar fato específico pro contrato incha o arquivo que toda sessão paga pra ler; mandar pra memória semântica no máximo custa esperar o assunto aparecer. Na dúvida, memória semântica.

---

## Parte 3: como as peças se conectam

```
projeto/
├── .claude/
│   ├── hooks/
│   │   └── load-recent.sh        # injeta o _resume.md na abertura de toda sessão
│   ├── commands/
│   │   ├── save.md               # /save: fecha a sessão (diário + curadoria + resumo)
│   │   ├── save-crisis.md        # /save pra sessão de incidente
│   │   ├── resume.md             # /resume: recap sob demanda
│   │   └── write-task.md         # /write-task: registra problema adiado
│   ├── write-task-check.sh       # valida a task; recusa registro raso
│   └── settings.json             # registra o hook de abertura
└── .claude-memory/               # diários (gitignored, só na sua máquina)
    ├── 2026-03-12.md             # um diário por dia
    └── _resume.md                # síntese de 5 bullets, reescrita a cada /save
```

### O que é padrão do Claude Code e o que este sistema adiciona

Importante ter claro: este sistema **não modifica nada interno do Claude Code**. Ele só adiciona arquivos, usando dois pontos de extensão oficiais (hooks e slash commands) e duas memórias que já vêm de fábrica. É por isso que remover é só apagar arquivos (Parte 6).

| Peça | De onde vem |
|---|---|
| `CLAUDE.md` carregado inteiro em toda sessão | **Padrão do Claude Code.** Existe com ou sem este sistema |
| Memória semântica (pasta `memory/` + índice `MEMORY.md`, injetada quando o assunto aparece) | **Padrão do Claude Code.** Existe com ou sem este sistema |
| Hooks (eventos como `SessionStart`, registrados em `.claude/settings.json`) | **Mecanismo padrão do Claude Code.** O script `load-recent.sh` que penduramos nele é deste sistema |
| Slash commands (arquivos `.md` em `.claude/commands/` que viram comandos `/nome`) | **Mecanismo padrão do Claude Code.** Os 4 comandos (`/save`, `/save-crisis`, `/resume`, `/write-task`) são deste sistema |
| Diários e resumo (`.claude-memory/`, `_resume.md`) | **Deste sistema.** O Claude Code não tem memória temporal nativa |
| Check de task (`write-task-check.sh`) | **Deste sistema** |

Em resumo: o Claude Code, sozinho, já te dá o contrato (`CLAUDE.md`) e a memória semântica. O que ele não tem é a camada temporal (diários + resumo na abertura) e os rituais de curadoria (`/save` e companhia). É isso que o sistema adiciona.

O ciclo de uma sessão de trabalho:

1. **Você abre o Claude Code no projeto.** O hook `SessionStart` roda `load-recent.sh`, que imprime o `_resume.md` pro contexto. O Claude começa sabendo onde tudo parou.
2. **Você trabalha normalmente.** Se um problema for descoberto mas adiado, `/write-task` o registra com a investigação completa.
3. **No fim da sessão, você roda `/save`.** Ele escreve o diário do dia, decide o que da sessão merece virar memória durável (e em qual camada, pela regra de fronteira), fecha tasks que a sessão resolveu e reescreve o `_resume.md` pra próxima sessão.

Um detalhe deliberado: o `/save` é **manual**. Dava pra automatizar com um hook de fim de sessão, e eu não recomendo. O ato consciente de fechar a sessão é parte do valor (você decide se ela mereceu registro), e a escolha entre `/save` e `/save-crisis` carrega um sinal que nenhuma automação captura: se o projeto está em modo normal ou em modo emergência.

---

## Parte 4: passo a passo

Pré-requisitos: [Claude Code](https://claude.com/claude-code) instalado, bash e git. Tempo: uns 15 minutos.

Atalho: se você clonou este repositório, `./install.sh /caminho/do/seu/projeto` executa os passos 1 a 6 de uma vez (e já copia os arquivos do passo 9). Ainda assim vale ler o passo a passo: ele explica o que cada peça faz e por quê.

Os passos 1 a 7 montam o núcleo. Os passos 8 a 10 são extensões: deixe pra depois, adote quando sentir a dor específica que cada uma resolve.

### Passo 1: criar a pasta de diários, fora do git

Na raiz do seu projeto:

```bash
mkdir -p .claude-memory
echo ".claude-memory/" >> .gitignore
```

Os diários são pessoais e locais por design: o leitor deles é o Claude da próxima sessão **na sua máquina**. Versionar diário de sessão no repo do time gera ruído sem leitor (ver Parte 5).

### Passo 2: criar o hook de abertura

"Hook" no Claude Code é um script que roda automaticamente em eventos da sessão; o evento `SessionStart` dispara na abertura, e **tudo que o script imprimir em stdout entra no contexto do Claude**. Esse é o único mecanismo de leitura do sistema inteiro.

Crie `.claude/hooks/load-recent.sh` com o conteúdo abaixo e dê permissão de execução (`chmod +x .claude/hooks/load-recent.sh`):

```bash
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
```

### Passo 3: registrar o hook

O Claude Code descobre os hooks pelo `.claude/settings.json` do projeto. Crie o arquivo (ou, se já existir, adicione o bloco `SessionStart` ao que está lá):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/load-recent.sh"
          }
        ]
      }
    ]
  }
}
```

**Teste:** crie um diário de mentira (`echo "- teste do hook" > .claude-memory/2020-01-01.md`, com data de hoje no nome do arquivo pra cair na janela de 48h) e abra uma sessão nova do Claude Code no projeto. Pergunte "o que apareceu no seu contexto sobre diário?". Ele deve citar o conteúdo. Apague o arquivo de teste depois.

### Passo 4: criar o comando `/save` (o coração do sistema)

"Slash command" no Claude Code é um arquivo markdown em `.claude/commands/`: quando você digita `/save`, o conteúdo do arquivo vira o prompt da vez. Ou seja, o comando abaixo não é código, são **instruções que o Claude executa** quando você o invoca.

Crie `.claude/commands/save.md`:

````markdown
---
description: Salva resumo da sessão atual em .claude-memory/YYYY-MM-DD.md
---

Salva um resumo desta sessão em `.claude-memory/YYYY-MM-DD.md` (use a data de hoje em UTC no nome do arquivo).

`/save` é um **log do que aconteceu nesta sessão**: eventos com tempo. Não é auditoria do estado atual do projeto, não é varredura por inconsistências entre arquivos, não é detecção especulativa de conflitos. Se algo não foi tocado nem discutido nesta sessão, não entra no diário.

**Antes de escrever**, liste mentalmente o que aconteceu:
- Mudanças concretas (arquivos editados, scripts criados, deploys, infra tocada)
- Decisões técnicas/produto (com o "porquê", não só o "o quê")
- Problemas/bugs encontrados ou discutidos **nesta sessão** (resolvidos ou não)
- Pendências geradas **nesta sessão** (o que ficou em aberto)
- Mudanças de direção (algo discutido que invalidou abordagem anterior)
- Aprendizados não-óbvios sobre o sistema/dados que custaram tempo

Aplique o filtro **"isso vai importar daqui a 1 semana?"** a cada item. Se sim, inclua. Decida sozinho, não pergunte ao usuário "vale salvar isso?". Errar pra mais é melhor que pra menos.

**Regra anti-alucinação (inviolável)**: se for citar, contrastar ou afirmar algo sobre o conteúdo de outro arquivo (CLAUDE.md, memória semântica, schema, código, config), **leia o arquivo com `Read` antes** de escrever a afirmação. Nunca inferir conteúdo a partir do nome do arquivo. Se não conseguiu/quis ler, não cite. Aspas só com o texto exato do arquivo, copiado de uma leitura desta sessão.

Requisitos do diário:
- Máximo 15 bullets (se exceder, priorize: pendências > decisões > problemas > feito; "feito" mais óbvio já está no git)
- **Título no topo**: `# YYYY-MM-DD` (sem frontmatter)
- Estruturado nas seguintes seções (omita seção vazia):
  - **Feito**: o que foi concluído nesta sessão
  - **Decisões**: decisões técnicas ou de produto tomadas (com o "porquê")
  - **Problemas**: bugs encontrados ou dificuldades
  - **Pendente**: o que ficou em aberto pra próxima sessão

Se já existir arquivo para hoje, faça merge inteligente: integre os pontos novos sem duplicar o que já estava lá.

**Pass obrigatório: triagem das camadas duráveis**. Existem duas camadas que sobrevivem entre sessões: o **CLAUDE.md** (sempre-carregado, com precedência, caro) e a **memória semântica** (a pasta de memória nativa do projeto, injetada automaticamente quando o tópico aparece). A **regra de fronteira** decide o destino: *o fato precisa estar no contexto em toda sessão, ou só quando o assunto dele aparece?* Toda sessão → CLAUDE.md; só quando aparece → memória. A cada `/save`, faça os passos:

1. **Há algo significativo desta sessão pra registrar?** Regra de trabalho nova, decisão de arquitetura, restrição, preferência do usuário, schema/procedimento de subsistema, gotcha localizado, referência externa estável. Se sim, **decida o destino pela regra de fronteira** e proponha a edição:
   - **Contrato (CLAUDE.md)**: o que molda comportamento independente do tópico (regra inviolável, autorização durável, preferência sempre-aplicável). Local se específico ao projeto, global (`~/.claude/CLAUDE.md`) se vale pra todos os projetos.
   - **Memória semântica**: o que só importa quando seu tópico/arquivo/pessoa aparece (schema de subsistema, procedimento de deploy, gotcha localizado, referência). Escrever no formato nativo do Claude Code (um fato por arquivo + linha no índice `MEMORY.md`); não reinventar formato.
   - Aplica a regra anti-alucinação: leia o trecho-alvo antes de editar. Se nada significativo aconteceu, diga isso e não force entrada.
2. **O contrato ainda cabe?** CLAUDE.md é caro (carrega inteiro, toda sessão). Antes de acrescentar, avalie o tamanho atual: se já está grande, a primeira pergunta é se a entrada nem deveria ir pro contrato. Boa parte do que incha um CLAUDE.md é específico-por-tópico que pertence à memória. Proponha **mover pra memória** o que é recuperável-sob-demanda, e **podar** o obsoleto/redundante/superado, não só acrescentar no fim. Objetivo: contrato enxuto e sempre-verdadeiro. Limpeza maior, sinalize ao usuário.
3. **Ainda é verdade?** Fato errado numa camada durável é armadilha pro eu-futuro, que confia nele *porque* está salvo. Se a sessão tocou uma área cuja estrutura o CLAUDE.md (ou uma memória) descreve (qual módulo faz o quê, invariantes, topologia), **re-verifique por amostragem** os trechos relevantes contra o código real (Read/grep, não memória) e corrija o que apodreceu. Não é varredura cega a cada save, só os fatos que a sessão tocou.

CLAUDE.md é versionado (diferente do diário): edições nele seguem a regra normal de commit do projeto.

**Pass: reconciliação de tasks (`/write-task`)**. Se o projeto usa o `/write-task`, varra a pasta de memória semântica **deste** projeto por arquivos `task-*.md`. Para cada task que ainda não tem `**Estado:** fechada` e que **esta sessão resolveu de fato** (existe commit/arquivo desta sessão que a fecha; não feche por suposição):

1. Edite a task: `**Estado:** fechada` + uma linha de como foi (commit/arquivo).
2. Grave `**Desfecho:**` com **default pessimista**: `pela-task` só se a sessão que resolveu **usou** o `## Como resolver`/`## O que achei` da task e bateu; na menor dúvida, `reinvestiguei`; `obsoleta` se deixou de importar sem ser resolvida. Meia linha de evidência (o que da task foi usado, ou o que faltou).

Escopo enxuto de propósito: não interrogar sobre cada task aberta, não fechar o que só *parece* resolvido. **Não fechar nada é o caso comum** e está ok. Liste no resumo final quais tasks fechou e com qual desfecho, pra o usuário poder vetar. Aplica a regra anti-alucinação: leia a task antes de reescrever.

**Pass final: `_resume.md`**. Gere/sobrescreva `.claude-memory/_resume.md` com uma síntese de exatamente 5 bullets, que é o que o hook `SessionStart` mostra quando o usuário abre uma nova sessão. Use os diários da janela recente (últimas ~48h em `.claude-memory/`) + `CLAUDE.md` como fontes. Estrutura:

```
1. **Onde estamos**: estado atual do projeto numa frase
2. **Regras invioláveis (do CLAUDE.md)**: se o CLAUDE.md do projeto tem seção de regras invioláveis ("Regras pétreas", "Invioláveis", "Leia primeiro"), reproduzir lista numerada curta (1 linha por regra). NÃO inventar regra que não está no CLAUDE.md. Se o projeto não tem essa seção, omita esse bullet e desça os outros pra preencher 5 totais.
3. **Últimas sessões**: o que foi feito recentemente
4. **Decisões e notas efêmeras**: contexto da semana, planos provisórios, observações que ainda não viraram regra. **Não confundir com o bullet 2**: o que está aqui é hipótese em avaliação, não restrição inviolável.
5. **Pendente + próximo passo lógico**: a próxima ação concreta primeiro, depois a lista de pendências
```

**Por que regras invioláveis separadas das notas da semana**: numa sessão real, uma regra inviolável foi misturada com decisões provisórias, e um plano antigo que violava a regra acabou propagado como "decisão validada". Separar deixa explícito o que é restrição vs hipótese.

Esse arquivo substitui o que o hook mostra no SessionStart, sobrescrito a cada `/save`. Mantenha enxuto: cada bullet ≤ 2 linhas (exceto o bullet 2 quando lista regras).

**Transição saindo de crise**: antes de sobrescrever o `_resume.md`, leia o atual. Se ele abre com o banner `⚠ INCIDENTE EM ABERTO` (escrito por um `/save-crisis` anterior) e o usuário rodou `/save` (não `/save-crisis`), trate como sinalização explícita de fechamento do incidente:
- NÃO reproduzir banner de urgência nem vocabulário herdado do `/save-crisis` ("mesma urgência", "não tratar como sprint", "seguem críticos").
- Pendências remanescentes do incidente entram como follow-ups normais em tom de rotina, misturadas ao resto das pendências sem peso especial.
- Diários antigos do incidente ficam intactos: histórico não se reescreve. Só o `_resume.md` muda de temperatura.
- Se o incidente **não** está fechado de verdade, o usuário deveria ter rodado `/save-crisis`. Não compense reaquecendo o resume; confie no comando que ele escolheu.

**Validação obrigatória ao montar o `_resume.md`**: se um diário antigo lista "pendência" ou "conflito" que cita arquivos específicos (ex.: "CLAUDE.md diz X mas a memória diz Y"), **leia os arquivos citados no estado atual** antes de copiar pro resume. Se já não bate (arquivo mudou, conflito resolvido, ou nunca existiu como descrito), **descarte a alegação**: não copie pro resume mesmo que esteja no diário. Diários são imutáveis e podem conter erro registrado; o `_resume.md` reflete o estado atual verificado.

Após salvar:
1. Mostre os caminhos: diário do dia, `_resume.md`, e qualquer edição proposta/aplicada no `CLAUDE.md`.
2. Não commite o diário (`.claude-memory/` está no gitignore). Edições no `CLAUDE.md` (versionado) seguem a regra normal de commit do projeto.
````

É longo porque quase tudo ali é **regra de comportamento**, não formato. Em resumo, o `/save` faz 4 coisas, nesta ordem:

1. **Escreve o diário do dia** (máximo 15 bullets, seções Feito / Decisões / Problemas / Pendente), filtrando pelo teste "isso importa daqui a 1 semana?".
2. **Tria o que é durável**: promove fatos da sessão pra camada certa (contrato ou memória semântica, pela regra de fronteira) e aproveita pra podar o `CLAUDE.md` do que apodreceu.
3. **Fecha tasks que a sessão resolveu** (se você adotar o `/write-task` do passo 9).
4. **Reescreve o `_resume.md`**, os 5 bullets que a próxima sessão vai receber na abertura.

Pra dar concretude, um `_resume.md` real tem essa cara:

```markdown
1. **Onde estamos**: API de pagamentos com o checkout novo em beta; falta migrar os webhooks legados.
2. **Regras invioláveis (do CLAUDE.md)**: 1) nunca rodar migration em produção sem backup; 2) todo endpoint novo exige teste de contrato.
3. **Últimas sessões**: implementado retry com backoff nos webhooks (12/03); corrigido o timeout do gateway (11/03).
4. **Decisões e notas efêmeras**: avaliando trocar a fila por SQS; sem decisão ainda.
5. **Pendente + próximo passo**: migrar os 3 webhooks legados pro handler novo; depois remover a feature flag do checkout.
```

E um diário de um dia:

```markdown
# 2026-03-12

## Feito
- Retry com backoff exponencial nos webhooks (`webhooks/retry.ts`)

## Decisões
- Teto de backoff em 1h, porque o gateway limita a 100 req/min

## Problemas
- Sandbox do gateway devolve 500 intermitente; não reproduz em produção

## Pendente
- Migrar os 3 webhooks legados pro handler novo
```

**Teste:** trabalhe uma sessão normal (ou simule: peça pro Claude fazer qualquer mudança pequena), rode `/save`, e confira os dois arquivos gerados em `.claude-memory/`. Depois abra uma sessão nova: o resumo deve aparecer logo no início, e o Claude deve responder "o que estávamos fazendo?" sem você explicar nada.

### Passo 5: criar o comando `/resume`

Recap sob demanda, pra quando você quer re-situar no meio de uma sessão. Crie `.claude/commands/resume.md`:

```markdown
---
description: Resume o que estava acontecendo nas últimas sessões
---

Com base nos arquivos em `.claude-memory/` (diários recentes) e em `CLAUDE.md` (decisões duráveis), me diga em até 5 bullets:

1. Em que ponto do projeto estamos
2. O que foi feito nas últimas sessões
3. Decisões recentes que ainda valem
4. O que estava pendente
5. Qual o próximo passo lógico

Seja direto, sem preâmbulo. Se faltar informação pra algum item, diga "sem dados" naquele bullet em vez de inventar.
```

### Passo 6: criar o comando `/save-crisis`

Use no lugar do `/save` quando a sessão termina com um incidente em aberto (vazamento, auditoria com achados críticos, produção quebrada). Ele existe como **comando separado**, e não como uma opção do `/save`, de propósito: o ato de escolher qual dos dois rodar é a informação ("o projeto está em modo normal ou em emergência?").

Crie `.claude/commands/save-crisis.md`:

````markdown
---
description: /save pra sessão de incidente/crise/auditoria; preserva o tom de urgência no _resume.md
---

Use **em vez de** `/save` quando a sessão fecha com **incidente / auditoria com findings críticos / vazamento em produção** em aberto. A próxima sessão precisa abrir tratando como emergência, não como sprint.

Faz tudo que o `/save` faz (mesmas regras de diário, anti-alucinação, curadoria do CLAUDE.md), com **duas diferenças**. O sinal de crise vive **só no `_resume.md`** (o banner abaixo): é ele que a próxima sessão lê e que o `/save` normal detecta pra voltar ao tom de rotina.

## 1. `_resume.md` abre com bloco de urgência

Antes dos 5 bullets padrão, começa com:

```
> ⚠ INCIDENTE EM ABERTO: não tratar como sprint
>
> Natureza: <uma frase>
> Impacto: <quem/o quê está exposto>
> Status: <N fechados / M abertos>
> Última ação: <o que a sessão anterior fez, com pointer pro diário>
>
> Bugs adjacentes da mesma família **são da mesma urgência**: não viram "rodada futura", "polimento" ou "backlog". Se afeta N itens e fechamos M < N, os restantes seguem críticos.
```

Os 5 bullets normais seguem **depois** do bloco. No bullet de Pendente, listar **nominalmente** os itens críticos remanescentes: não condensar em "itens 8-30" nem em síntese vaga.

## 2. Anti-suavização (inviolável neste comando)

Ao escrever Pendente (do diário e do `_resume.md`):
- **Não** consolidar findings críticos em síntese vaga ("vários itens de polimento", "backlog de cleanup").
- **Não** reordenar itens da família do incidente pra depois de polimento. Manter ordem por severidade.
- **Não** marcar "concluído" o que foi mitigado parcialmente: usar "mitigação parcial: X feito, Y falta".

## Como o tom volta ao normal

Quando o usuário considerar o incidente fechado, ele roda o `/save` normal, que sobrescreve o `_resume.md` sem o bloco de urgência. O ato de escolher `/save` em vez de `/save-crisis` **é** a sinalização de fechamento. Sem prazo automático, sem heurística: o usuário decide explicitamente.

## Após salvar

Igual ao `/save`:
1. Mostre os caminhos: diário do dia, `_resume.md`, e qualquer edição proposta/aplicada no `CLAUDE.md`.
2. Não commite o diário (`.claude-memory/` está no gitignore). Edições no `CLAUDE.md` (versionado) seguem a regra normal de commit.
````

### Passo 7: adotar o ritual

A mecânica está pronta. O que falta é hábito, e é um só: **no fim de toda sessão substantiva, rode `/save`** (regra prática: 3 ou mais mudanças significativas, ou uma decisão de arquitetura, ou mais de 30 minutos de trabalho). Sessão trivial não precisa.

Vale adicionar uma linha no `CLAUDE.md` do projeto pedindo pro Claude **sugerir** o `/save` no fim de sessões substantivas, mas a decisão de rodar é sua, pelo motivo do fim da Parte 3.

**Núcleo completo.** Use por 2 ou 3 semanas antes de considerar as extensões abaixo.

---

### Passo 8 (extensão): memória semântica

O Claude Code tem memória nativa por projeto: uma pasta com um arquivo por fato e um índice (`MEMORY.md`), que ele injeta automaticamente no contexto quando o assunto correspondente aparece na conversa. O `/save` do passo 4 já sabe usar essa camada: é o destino "memória semântica" da triagem. Você não precisa configurar nada além de deixar o `/save` escrever lá quando propuser.

O aviso importante, pago com experiência própria: **não construa uma camada dessas por conta própria sem um mecanismo de leitura automática**. A primeira versão do meu sistema tinha uma pasta de "fatos duráveis" custom, e ela morreu: sem nada que injetasse os arquivos sozinho, ninguém (nem o Claude, nem eu) os lia espontaneamente. A camada só voltou a existir quando o Claude Code ganhou o recall nativo. Memória que ninguém lê é custo de escrita puro.

### Passo 9 (extensão): `/write-task`, registrando problema adiado sem perder a investigação

O cenário: no meio de uma tarefa você descobre um bug, mas ele não vai ser resolvido agora. O reflexo natural é anotar uma linha ("export CSV estoura timeout") e seguir. Semanas depois, a anotação está lá, mas a investigação (qual arquivo, qual mecanismo, o que já foi testado) morreu com a sessão, e alguém paga tudo de novo.

O `/write-task` registra o problema como um arquivo de task na memória semântica, com 5 seções obrigatórias. E aqui está o aprendizado central desta peça: **o template não basta**. Um modelo de linguagem preenche qualquer template com generalidades plausíveis ("Como resolver: investigar o worker") e dá a tarefa por feita. O que dá dente ao comando é um **script de validação que falha**: ele recusa a task se as seções não citarem arquivo/símbolo concreto, e o comando instrui o Claude a não dar a task por criada enquanto o script não passar.

Crie `.claude/commands/write-task.md`:

````markdown
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
````

E o script de validação, `.claude/write-task-check.sh` (com `chmod +x`):

```bash
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
```

Uma task que passa no check tem essa cara:

```markdown
---
name: task-timeout-export-csv
description: Export CSV estoura timeout com mais de 50k linhas no relatório de vendas
metadata:
  type: project
---

## Causa-raiz
O export monta o CSV inteiro em memória antes de responder; acima de ~50k
linhas o request passa dos 30s do gateway.

## O que achei
`reports/export.ts:88`: `buildCsv()` acumula tudo num array e só escreve no
fim. O limite de 30s vem do `nginx.conf` (`proxy_read_timeout 30s`).
Reproduzi com o relatório de vendas de março (52k linhas): 34s.

## Como resolver
Trocar `buildCsv()` por streaming em `reports/export.ts`: escrever linha a
linha na response com `res.write()`, removendo o array acumulador.

## Como testar
`curl -o /dev/null -w '%{time_total}' 'https://app.local/reports/vendas.csv?mes=2026-03'`
deve completar abaixo de 30s e o arquivo deve abrir com as 52k linhas.

**Estado:** aberta
```

Sobre a métrica de `Desfecho`: a taxa de sucesso do sistema é `pela-task / (pela-task + reinvestiguei)`. Existe um 4º valor, `retroativo`, só pra fechar task antiga de antes da métrica existir sem inventar um sucesso que ninguém mediu (conta como fechada, fica fora da taxa). Um dado do mundo real: na primeira medição que fiz sobre 18 tasks, 11 estavam fora do protocolo (campo `Estado` ausente ou preenchido com prosa). O obstáculo não era falta de métrica, era aderência ao próprio protocolo. Por isso o check aceita sinônimos naturais (`resolvida`, `concluída`) em vez de brigar com o vocabulário que o uso real produz, e rejeita prosa de status, que nenhum script consegue agregar.

### Passo 10 (extensão): instalar em vários projetos

Quando o sistema estiver rodando bem num projeto, os dois scripts deste repositório resolvem a escala:

- **`install.sh`** (instalação one-shot): `./install.sh /caminho/do/projeto` copia hook, commands e o check pro `.claude/` do projeto-alvo, cria o `settings.json` se não existir (se existir, avisa pra você fundir na mão em vez de sobrescrever), cria `.claude-memory/` e ajusta o `.gitignore`. Ele já trata um caso não-óbvio: se um gitignore global da sua máquina ignora `.claude/`, acrescenta a exceção (`!.claude/` e `!.claude/**`) no `.gitignore` local, senão hooks e commands nunca entram no git do projeto. Um alias no shell deixa a adoção a um comando de distância.
- **`propagate.sh`** (atualização de quem já adotou): descobre os projetos adotantes **varrendo** um diretório de projetos (variável `PROJECTS_DIR`; default: o diretório pai deste repositório), nunca por lista fixa no script, que apodrece. Compara cada arquivo do tooling com a cópia instalada, copia só o que mudou e commita por projeto, só os arquivos propagados. `--dry-run` mostra as diferenças sem tocar em nada; `--no-commit` só copia.

No repositório do tooling em si, faça a instância local usar **simlinks** de `.claude/commands/` pros arquivos-fonte: editar o comando e testá-lo viram a mesma ação.

---

## Parte 5: o que eu construí, medi e joguei fora

Tão importante quanto a receita é a lista do que **não** repetir. Cada peça abaixo foi construída, usada de verdade e cortada. O método de corte: toda aposta nova entra com um "critério de morte" explícito e uma data de revisão ("se até tal data isso não provou X, morre"), e o desfecho se executa sem apego.

| Peça morta | O que era | Por que morreu |
|---|---|---|
| Agregação entre projetos | Diários de todos os projetos sincronizados num repositório central | Nenhum leitor real. O ganho vem do resumo injetado na abertura da sessão, não de revisitar histórico. Em meses de uso, a revisita simplesmente não acontecia |
| Tags temáticas nos diários | Frontmatter com tags pra permitir busca cruzada por tema | O consumidor das tags era a agregação acima; morta ela, as tags viraram custo de escrita puro |
| Arquivo central de decisões | Um `decisions.md` com as decisões de todos os projetos | Redundante: tudo que valia a pena já vivia nos `CLAUDE.md` (do projeto ou global). Camada nova só se justifica se as existentes não cobrem |
| Trava de edição em arquivo "decidido" | Hook que bloqueava editar arquivo coberto por uma decisão registrada, pedindo confirmação | Inviável no uso: fricção a cada edição legítima, e em semanas nunca interceptou um erro real. Proteger decisão é papel de check executável no repositório do trabalho (teste, lint, CI), não do tooling de memória |
| Memória semântica caseira | A camada do passo 8, versão própria, antes do recall nativo do Claude Code existir | Sem um mecanismo que injetasse os arquivos automaticamente, ninguém os lia. Reativada só quando a leitura automática passou a existir |

Os princípios que essas mortes ensinam, e que valem pra qualquer sistema de memória de agente:

- **Toda peça precisa provar que tem leitor.** Não "seria útil se alguém lesse", mas "foi lido, quando, com qual efeito". Aposta nova entra com critério de morte e data de revisão.
- **Concisão é o produto.** O valor vem do tamanho e do foco do que é injetado no contexto, não do volume acumulado em disco. Cada expansão precisa se pagar em atenção.
- **Regra escrita não segura comportamento; script que falha, sim.** Instrução em texto ("sempre preencha com detalhes") é ignorável por LLM e por humano. O que segura é validação executável que recusa o resultado ruim (o `write-task-check.sh` existe por isso). E verificação em ritual separado é contornada: acople ao ritual que já acontece (o fechamento de task vive dentro do `/save` por isso).
- **Reativo por design.** Sem rotina autônoma, sem reindexação em background, sem pipeline paralelo: tudo dispara por ação sua dentro de uma sessão. Cada automação a mais é mais uma coisa que apodrece em silêncio.

---

## Parte 6: como remover e voltar ao padrão

O sistema é 100% aditivo: são arquivos em `.claude/` e `.claude-memory/`, pendurados em pontos de extensão oficiais. Desinstalar é apagá-los; nada do Claude Code precisa ser reinstalado ou reconfigurado.

**1. Apague os arquivos do sistema:**

```bash
rm -rf .claude-memory
rm .claude/hooks/load-recent.sh
rm .claude/commands/save.md .claude/commands/save-crisis.md \
   .claude/commands/resume.md .claude/commands/write-task.md
rm .claude/write-task-check.sh
```

**2. Desregistre o hook.** Abra `.claude/settings.json` e remova o bloco `SessionStart` que aponta pro `load-recent.sh` (adicionado no passo 3). Se o arquivo foi criado por este tutorial e não contém mais nada, pode apagar o arquivo inteiro.

**3. Limpe o `.gitignore`** (opcional): remova a linha `.claude-memory/`. Deixar não quebra nada.

**4. Decida sobre o conteúdo que o sistema escreveu nas camadas nativas.** Aqui vale a fronteira da tabela da Parte 3: o `CLAUDE.md` e a memória semântica são **padrão do Claude Code** e continuam funcionando normalmente depois da remoção. O que o `/save` escreveu neles (regras promovidas ao `CLAUDE.md`, fatos na pasta `memory/`) é conteúdo seu, não do sistema, e provavelmente vale manter. A exceção são as tasks do `/write-task`: se quiser removê-las, apague os `task-*.md` da pasta de memória do projeto e as linhas correspondentes no `MEMORY.md`.

Resultado: o Claude Code volta ao comportamento de fábrica. Sessões novas abrem sem o resumo (de volta ao cold start), os comandos `/save`, `/save-crisis`, `/resume` e `/write-task` deixam de existir, e o `CLAUDE.md` + memória semântica seguem funcionando como sempre funcionaram, porque nunca foram do sistema.

---

## Fechando

O sistema inteiro: 2 scripts bash pequenos, 4 comandos em markdown, 1 check. O código é trivial de propósito. O valor está nas regras de comportamento dentro dos comandos: o filtro "importa daqui a 1 semana?", a regra anti-alucinação, a regra de fronteira entre as 3 camadas, o default pessimista da métrica, a saída consciente de crise.

Roteiro sugerido: passos 1 a 7 hoje, use por 2 ou 3 semanas, e só então adote as extensões cuja dor você sentiu. E quando for construir algo em cima, dê à peça nova um critério de morte antes de dar um roadmap.
