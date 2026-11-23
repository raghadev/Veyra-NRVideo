<!--
Sync Impact Report (2.0.0)
- Versão: 1.0.0 -> 2.0.0 (MAJOR: princípio IV redefinido)
- Motivo: "nunca descartar o que o antigo entregaria" é impossível com qualquer espera menor que a
  antiga no quadro não reconstruível; o princípio passa a exigir evidência medida para encurtar,
  subida imediata na chegada tardia, piso e teto fixos e contagem visível.
- Modelos: sem impacto; spec.md já descreve espera adaptativa com piso e teto (FR-003, FR-004).

Sync Impact Report (1.0.0)
- Versão: modelo vazio -> 1.0.0 (primeira ratificação)
- Princípios criados: I Medido, não prometido; II Patch mínimo e rastreável; III Teste com sabotagem;
  IV Nunca pior que antes; V Windows primeiro, falha silenciosa e segura
- Seções criadas: Restrições técnicas; Fluxo de trabalho
- Modelos: plan-template.md (Constitution Check genérico, preenchido por plano) ✅ sem mudança;
  spec-template.md ✅ sem mudança; tasks-template.md ✅ sem mudança
- Pendências: nenhuma
-->
# Veyra Baixa Latência PS5 Constitution

## Core Principles

### I. Medido, não prometido
Nenhum número de atraso entra em texto, tela ou relatório sem ter sido medido. Atraso zero é
fisicamente impossível: o objetivo é cortar espera inútil, nunca prometer zero. Valor que a sessão
não mede aparece como traço, nunca estimado. Teste em simulação prova a lógica; só o hardware real
(PS5 + rede + PC) prova o ganho, e o relatório diz qual dos dois foi feito.

### II. Patch mínimo e rastreável sobre o chiaki fixado
Toda mudança no chiaki-ng entra como patch numerado em `scripts/remoteplay/patches/`, aplicado sobre
o commit fixado em `dependency-lock.json`, depois dos patches anteriores, e verificado por
`scripts/remoteplay/verify-chiaki-stage.py`. A licença AGPLv3 do chiaki-ng é preservada e cada arquivo
alterado fica descrito no lock. O comportamento antigo continua disponível por uma constante.

### III. Teste com sabotagem (inegociável)
Toda lógica nova nasce com teste que falha antes do código existir e que volta a falhar quando o
defeito é plantado de propósito. Teste que nunca ficou vermelho não conta. O esperado de cada teste é
um valor fixo calculado à mão, nunca a mesma conta do código testado. Lógica portável é testada fora
do Windows sempre que possível; o que só existe no Windows é compilado contra os cabeçalhos do Windows
e declarado como não executado.

### IV. Nunca pior que antes onde dá para saber
Quando o quadro é reconstruível pela correção de erros, pular o pacote faltante não perde nada e é
obrigatório. Quando não é, nenhuma espera menor que a antiga garante o mesmo resultado (um pacote
pode chegar atrasado em qualquer momento), então a espera só encurta com evidência medida de que
aquela rede não reordena, volta a subir na primeira chegada tardia e nunca passa do teto antigo
(16 ms) nem desce do piso (2 ms). Toda chegada tardia é contada e mostrada, nunca escondida.

### V. Windows primeiro, falha silenciosa e segura
Recurso que depende do Windows carrega a API em tempo de execução, nunca impede a sessão de abrir
quando falha, só mexe na placa de rede durante a sessão e desfaz tudo ao terminar, inclusive em erro.

## Restrições técnicas

- chiaki-ng em C compatível com MSVC: sem VLA (o patch 0001 existe por isso), sem dependência nova.
- Veyra em C++20, Windows x64, Qt/QML; contrato do HUD: valor não reportado mostra traço.
- Nenhuma credencial, chave ou dado de conta PSN em log, teste ou texto de spec.
- Testes do chiaki usam o munit que já vem no repositório; testes do Veyra seguem `tests/remoteplay`.

## Fluxo de trabalho

- Spec Kit: spec, plano e tarefas antes do código; o código segue `tasks.md`.
- Um crítico de contexto limpo abre o artefato real (diff, build, testes) antes de qualquer "pronto".
- Commit, push, release e mensagens só com pedido explícito do dono do fork.
- Regras do repositório Veyra (`AGENTS.md`) continuam valendo onde não conflitam com esta constituição.

## Governance

Esta constituição vale para o ramo `baixa-latencia-ps5` e para as features em `specs/`. Emenda exige
registro no Sync Impact Report, versão semântica (MAJOR remove ou redefine princípio, MINOR acrescenta,
PATCH esclarece) e revisão de spec e plano afetados. Toda revisão de tarefa confere os cinco princípios.

**Version**: 2.0.0 | **Ratified**: 2026-11-23 | **Last Amended**: 2026-11-23
