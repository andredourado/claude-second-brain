---
description: /save para sessão de incidente/crise/auditoria; preserva o tom de urgência no _resume.md
---

Use **em vez de** `/save` quando a sessão fecha com **incidente / auditoria com findings críticos / vazamento em produção** em aberto. A próxima sessão precisa abrir tratando como emergência, não como sprint.

Faz tudo que o `/save` faz (mesmas regras de diário, anti-alucinação, curadoria do CLAUDE.md), com **duas diferenças**. O sinal de crise vive **só no `_resume.md`** (o banner abaixo): é ele que a próxima sessão lê e que o `/save` normal detecta para voltar ao tom de rotina.

## 1. `_resume.md` abre com bloco de urgência

Antes dos 5 bullets padrão, começa com:

```
> ⚠ INCIDENTE EM ABERTO: não tratar como sprint
>
> Natureza: <uma frase>
> Impacto: <quem/o quê está exposto>
> Status: <N fechados / M abertos>
> Última ação: <o que a sessão anterior fez, com pointer para o diário>
>
> Bugs adjacentes da mesma família **são da mesma urgência**: não viram "rodada futura", "polimento" ou "backlog". Se afeta N itens e fechamos M < N, os restantes seguem críticos.
```

Os 5 bullets normais seguem **depois** do bloco. No bullet de Pendente, listar **nominalmente** os itens críticos remanescentes: não condensar em "itens 8-30" nem em síntese vaga.

## 2. Anti-suavização (inviolável neste comando)

Ao escrever Pendente (do diário e do `_resume.md`):
- **Não** consolidar findings críticos em síntese vaga ("vários itens de polimento", "backlog de cleanup").
- **Não** reordenar itens da família do incidente para depois de polimento. Manter ordem por severidade.
- **Não** marcar "concluído" o que foi mitigado parcialmente: usar "mitigação parcial: X feito, Y falta".

## Como o tom volta ao normal

Quando o usuário considerar o incidente fechado, ele roda o `/save` normal, que sobrescreve o `_resume.md` sem o bloco de urgência. O ato de escolher `/save` em vez de `/save-crisis` **é** a sinalização de fechamento. Sem prazo automático, sem heurística: o usuário decide explicitamente.

## Após salvar

Igual ao `/save`:
1. Mostre os caminhos: diário do dia, `_resume.md`, e qualquer edição proposta/aplicada no `CLAUDE.md`.
2. Não commite o diário (`.claude-memory/` está no gitignore). Edições no `CLAUDE.md` (versionado) seguem a regra normal de commit.
