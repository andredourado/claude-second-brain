# Second brain para o Claude Code

Memória persistente entre sessões do Claude Code, feita de **markdown, bash e git**. Sem banco de dados, sem servidor, sem dependência além do próprio Claude Code. Em uso em produção em quase 20 projetos reais.

O problema que resolve: o Claude Code não lembra de nada entre sessões. Decisões, becos sem saída já explorados e pendências evaporam quando a janela fecha, e a sessão seguinte re-explica ou re-deduz tudo. Com este sistema, toda sessão nova abre já sabendo onde o projeto parou, o que foi decidido e qual o próximo passo.

## O que você ganha

- **Fim do cold start**: um resumo de 5 bullets é injetado automaticamente na abertura de toda sessão.
- **Memória no lugar certo**: 3 camadas com custos diferentes (regras sempre carregadas / fatos por tópico sob demanda / diários quase nunca carregados), para a memória não roubar atenção da tarefa.
- **`CLAUDE.md` sob controle**: o `/save` faz curadoria ativa em vez de só acumular linhas.
- **Problema adiado sem perder a investigação**: `/write-task` registra causa-raiz + evidências + onde corrigir, e um check executável recusa registro raso.
- **Incidente não vira "backlog"**: `/save-crisis` preserva a urgência entre sessões.
- **Zero infraestrutura**: tudo é markdown legível e bash curto; remover o sistema é apagar arquivos.

A lista completa, com o porquê de cada ganho, está no [TUTORIAL.md](TUTORIAL.md).

## Instalação rápida

```bash
git clone <url-deste-repo>
cd claude-second-brain
./install.sh /caminho/do/seu/projeto
```

O script cria `.claude/hooks/load-recent.sh` (hook de abertura), os comandos `/save`, `/save-crisis`, `/resume` e `/write-task`, o check `write-task-check.sh`, o `settings.json` (se não existir) e a pasta de diários `.claude-memory/` (fora do git). Depois é só trabalhar e rodar `/save` no fim das sessões.

Para entender o que cada peça faz (ou montar na mão, sem clonar), siga o **[TUTORIAL.md](TUTORIAL.md)**: os ganhos em detalhe, os 3 conceitos por trás do design, o passo a passo completo, o que é padrão do Claude Code vs o que o sistema adiciona, como remover, e a lista do que foi construído, medido e cortado.

## Estrutura

```
claude-second-brain/
├── TUTORIAL.md               # o tutorial completo (comece por ele)
├── install.sh                # instala num projeto (one-shot)
├── propagate.sh              # propaga updates para projetos que já adotaram
├── hooks/
│   └── load-recent.sh        # SessionStart: injeta o resumo no contexto
├── commands/
│   ├── save.md               # /save: diário + curadoria + resumo (o coração)
│   ├── save-crisis.md        # /save para sessão de incidente
│   ├── resume.md             # /resume: recap sob demanda
│   └── write-task.md         # /write-task: registra problema adiado
├── write-task-check.sh       # valida a task; recusa registro raso
└── settings.template.json    # registra o hook no projeto
```

## O ciclo de uma sessão

| Momento | O que acontece |
|---|---|
| **Início** | O hook injeta o `_resume.md` (5 bullets) no contexto |
| **Durante** | Trabalho normal; problema adiado vira `/write-task` |
| **Fim** | `/save`: diário do dia + triagem do que é durável + resumo para a próxima sessão |

## Como remover

O sistema é 100% aditivo: desinstalar é apagar os arquivos que ele criou e desregistrar o hook. Passo a passo na [Parte 6 do tutorial](TUTORIAL.md#parte-6-como-remover-e-voltar-ao-padrão).

## Licença

[MIT](LICENSE).
