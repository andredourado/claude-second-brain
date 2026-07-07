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

Aplique o filtro **"isso vai importar daqui a 1 semana?"** a cada item. Se sim, inclua. Decida sozinho, não pergunte ao usuário "vale salvar isso?". Errar para mais é melhor que para menos.

**Regra anti-alucinação (inviolável)**: se for citar, contrastar ou afirmar algo sobre o conteúdo de outro arquivo (CLAUDE.md, memória semântica, schema, código, config), **leia o arquivo com `Read` antes** de escrever a afirmação. Nunca inferir conteúdo a partir do nome do arquivo. Se não conseguiu/quis ler, não cite. Aspas só com o texto exato do arquivo, copiado de uma leitura desta sessão.

Requisitos do diário:
- Máximo 15 bullets (se exceder, priorize: pendências > decisões > problemas > feito; "feito" mais óbvio já está no git)
- **Título no topo**: `# YYYY-MM-DD` (sem frontmatter)
- Estruturado nas seguintes seções (omita seção vazia):
  - **Feito**: o que foi concluído nesta sessão
  - **Decisões**: decisões técnicas ou de produto tomadas (com o "porquê")
  - **Problemas**: bugs encontrados ou dificuldades
  - **Pendente**: o que ficou em aberto para a próxima sessão

Se já existir arquivo para hoje, faça merge inteligente: integre os pontos novos sem duplicar o que já estava lá.

**Pass obrigatório: triagem das camadas duráveis**. Existem duas camadas que sobrevivem entre sessões: o **CLAUDE.md** (sempre-carregado, com precedência, caro) e a **memória semântica** (a pasta de memória nativa do projeto, injetada automaticamente quando o tópico aparece). A **regra de fronteira** decide o destino: *o fato precisa estar no contexto em toda sessão, ou só quando o assunto dele aparece?* Toda sessão → CLAUDE.md; só quando aparece → memória. A cada `/save`, faça os passos:

1. **Há algo significativo desta sessão para registrar?** Regra de trabalho nova, decisão de arquitetura, restrição, preferência do usuário, schema/procedimento de subsistema, gotcha localizado, referência externa estável. Se sim, **decida o destino pela regra de fronteira** e proponha a edição:
   - **Contrato (CLAUDE.md)**: o que molda comportamento independente do tópico (regra inviolável, autorização durável, preferência sempre-aplicável). Local se específico ao projeto, global (`~/.claude/CLAUDE.md`) se vale para todos os projetos.
   - **Memória semântica**: o que só importa quando seu tópico/arquivo/pessoa aparece (schema de subsistema, procedimento de deploy, gotcha localizado, referência). Escrever no formato nativo do Claude Code (um fato por arquivo + linha no índice `MEMORY.md`); não reinventar formato.
   - Aplica a regra anti-alucinação: leia o trecho-alvo antes de editar. Se nada significativo aconteceu, diga isso e não force entrada.
2. **O contrato ainda cabe?** CLAUDE.md é caro (carrega inteiro, toda sessão). Antes de acrescentar, avalie o tamanho atual: se já está grande, a primeira pergunta é se a entrada nem deveria ir para o contrato. Boa parte do que incha um CLAUDE.md é específico-por-tópico que pertence à memória. Proponha **mover para a memória** o que é recuperável-sob-demanda, e **podar** o obsoleto/redundante/superado, não só acrescentar no fim. Objetivo: contrato enxuto e sempre-verdadeiro. Limpeza maior, sinalize ao usuário.
3. **Ainda é verdade?** Fato errado numa camada durável é armadilha para o eu-futuro, que confia nele *porque* está salvo. Se a sessão tocou uma área cuja estrutura o CLAUDE.md (ou uma memória) descreve (qual módulo faz o quê, invariantes, topologia), **re-verifique por amostragem** os trechos relevantes contra o código real (Read/grep, não memória) e corrija o que apodreceu. Não é varredura cega a cada save, só os fatos que a sessão tocou.

CLAUDE.md é versionado (diferente do diário): edições nele seguem a regra normal de commit do projeto.

**Pass: reconciliação de tasks (`/write-task`)**. Se o projeto usa o `/write-task`, varra a pasta de memória semântica **deste** projeto por arquivos `task-*.md`. Para cada task que ainda não tem `**Estado:** fechada` e que **esta sessão resolveu de fato** (existe commit/arquivo desta sessão que a fecha; não feche por suposição):

1. Edite a task: `**Estado:** fechada` + uma linha de como foi (commit/arquivo).
2. Grave `**Desfecho:**` com **default pessimista**: `pela-task` só se a sessão que resolveu **usou** o `## Como resolver`/`## O que achei` da task e bateu; na menor dúvida, `reinvestiguei`; `obsoleta` se deixou de importar sem ser resolvida. Meia linha de evidência (o que da task foi usado, ou o que faltou).

Escopo enxuto de propósito: não interrogar sobre cada task aberta, não fechar o que só *parece* resolvido. **Não fechar nada é o caso comum** e está ok. Liste no resumo final quais tasks fechou e com qual desfecho, para o usuário poder vetar. Aplica a regra anti-alucinação: leia a task antes de reescrever.

**Pass final: `_resume.md`**. Gere/sobrescreva `.claude-memory/_resume.md` com uma síntese de exatamente 5 bullets, que é o que o hook `SessionStart` mostra quando o usuário abre uma nova sessão. Use os diários da janela recente (últimas ~48h em `.claude-memory/`) + `CLAUDE.md` como fontes. Estrutura:

```
1. **Onde estamos**: estado atual do projeto numa frase
2. **Regras invioláveis (do CLAUDE.md)**: se o CLAUDE.md do projeto tem seção de regras invioláveis ("Regras pétreas", "Invioláveis", "Leia primeiro"), reproduzir lista numerada curta (1 linha por regra). NÃO inventar regra que não está no CLAUDE.md. Se o projeto não tem essa seção, omita esse bullet e desça os outros para preencher 5 totais.
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

**Validação obrigatória ao montar o `_resume.md`**: se um diário antigo lista "pendência" ou "conflito" que cita arquivos específicos (ex.: "CLAUDE.md diz X mas a memória diz Y"), **leia os arquivos citados no estado atual** antes de copiar para o resume. Se já não bate (arquivo mudou, conflito resolvido, ou nunca existiu como descrito), **descarte a alegação**: não copie para o resume mesmo que esteja no diário. Diários são imutáveis e podem conter erro registrado; o `_resume.md` reflete o estado atual verificado.

Após salvar:
1. Mostre os caminhos: diário do dia, `_resume.md`, e qualquer edição proposta/aplicada no `CLAUDE.md`.
2. Não commite o diário (`.claude-memory/` está no gitignore). Edições no `CLAUDE.md` (versionado) seguem a regra normal de commit do projeto.
