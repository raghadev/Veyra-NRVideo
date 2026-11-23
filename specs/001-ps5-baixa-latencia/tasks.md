# Tasks: Baixa latência no PS5 Remote Play

**Input**: Design documents from `/specs/001-ps5-baixa-latencia/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: obrigatórios (constituição, princípio III). Cada teste nasce vermelho e é sabotado depois.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [x] T001 Stage do chiaki fixado + patches 0001 a 0004 em `~/Desktop/DEV/chiaki-pin`, índice do git como base
- [x] T002 Compilar chiaki + testes no Mac (Ninja) e registrar a linha de base: 102/102 passando
- [x] T003 [P] Compilador cruzado para Windows disponível no Mac (mingw-w64) para checar o código Win32

## Phase 2: Foundational (bloqueia as histórias)

- [x] T004 Escrever `lib/include/chiaki/avreorder.h` conforme contracts/chiaki-avreorder.md (só tipos e assinaturas)
- [x] T005 Registrar `avreorder.c` em `lib/CMakeLists.txt` e `test/avreorder.c` em `test/CMakeLists.txt` + `test/main.c`

## Phase 3: User Story 1 - Pacote perdido não trava a imagem (P1) 🎯 MVP

### Testes (escrever primeiro, ver falhar)

- [x] T006 [US1] Teste unitário: lacuna de quadro reconstruível é pulada na hora (FR-001) em `test/avreorder.c`
- [x] T007 [US1] Teste unitário: unidade de correção faltando no fim de quadro já completo não segura o próximo (FR-002)
- [x] T008 [US1] Teste unitário: quadro não reconstruível espera a janela vigente e pula depois (FR-003)
- [x] T009 [US1] Teste unitário: pacote atrasado dentro da janela é entregue em ordem e conta como `late_fill` (FR-005)
- [x] T010 [US1] Teste unitário: chegada tardia após pulo por tempo sobe a janela na hora; após pulo por correção não sobe (FR-004)
- [x] T011 [US1] Teste unitário: sem reordenação a janela desce do teto ao piso em até 10 s (SC-004)
- [x] T012 [US1] Teste unitário: modo antigo (`adaptive=false`) reproduz 16 ms fixos e não pula por correção (FR-006)
- [x] T013 [US1] Teste unitário: virada do contador 65535 para 0 no meio de um quadro (revelou defeito no `reorderqueue.c` original: soma de 16 bits sem truncar)
- [x] T013b [US1] Teste unitário: lacuna logo depois do fim de um quadro pertence ao quadro seguinte (pega erro de um a mais na faixa)
- [x] T014 [US1] Simulação 60 fps com 1% de perda: retenção extra média por perda antiga x nova, quadros entregues (SC-001, SC-002)
- [x] T015 [US1] Simulação com reordenação até 3 ms sem perda: 100% dos quadros inteiros, zero pulo por tempo (SC-003)

### Implementação

- [x] T016 [US1] Implementar `lib/src/avreorder.c` (estado, classificação de chegada, flush, janela, estatísticas)
- [x] T017 [US1] Ligar no `lib/src/takion.c`: `on_arrival` antes do push, `flush` no lugar do antigo, timeout do recv pela política
- [x] T018 [US1] `ChiakiAvReorderStatsBox` em `ChiakiStreamConnection` (init/fini/reset) e ponteiro na `ChiakiTakionConnectInfo` (streamconnection e senkusha)
- [x] T019 [US1] Sabotar cada regra (pulo por correção, faixa de quadro, subida da janela, decaimento) e registrar o vermelho
- [x] T020 [US1] Gerar os patches (a correção da virada de 16 bits achada pelos testes virou `0005-chiaki-reorder-queue-16bit-wrap.patch`; a política virou `0006-chiaki-av-reorder.patch`), atualizar `verify-chiaki-stage.py`, `build-native.ps1`, `dependency-lock.json` e `THIRD_PARTY_NOTICES.md`, rodar o verificador

**Checkpoint**: chiaki com 5 patches compila, todos os testes antigos e novos passam no Mac.

## Phase 4: User Story 2 - Painel de atraso do PS5 (P2)

### Testes

- [x] T021 [P] [US2] Testes de `makeNetworkReadout` em `tests/remoteplay/CoreTests.cpp`: traço sem leitura anterior, taxa correta com valores fixos, contador que diminuiu vira traço, `valid=false` (FR-009, SC-006)

### Implementação

- [x] T022 [P] [US2] `include/veyra/remoteplay/NetworkReadout.h` + `src/remoteplay/NetworkReadout.cpp`; incluir no probe
- [x] T023 [US2] `NativeSnapshot` com campos `reorder*` e leitura em `ChiakiBackend::snapshot()`
- [x] T024 [US2] `RemotePlaySessionSource`: guardar o readout no laço de 1 s e expor `network()`
- [x] T025 [US2] `EngineController`: `remoteNetwork` no snapshot ao lado de `rates()`
- [x] T026 [US2] Ponte: `ps5Stream` (QVariantMap, NOTIFY snapshotChanged) em `QmlPlayerBridge.h` e `bridge/RemotePlay.cpp`
- [x] T027 [US2] `StreamHud.qml` com a linha do PS5 e `Main.qml` com o atalho ativo para PS5
- [x] T028 [US2] Incluir os arquivos novos nos alvos do produto (`CMakeLists.txt`/`cmake/VeyraRemotePlay.cmake`)

## Phase 5: User Story 3 - Wi-Fi sem varredura (P3)

### Testes

- [x] T029 [P] [US3] Testes de `WifiTuning` com API falsa: só placas conectadas, desfaz o que deu certo em ordem inversa, `NoWifi`, `ApiUnavailable`, falha parcial, destrutor sem exceção (FR-010, FR-011, SC-007)

### Implementação

- [x] T030 [P] [US3] `include/veyra/remoteplay/WifiTuning.h` + `src/remoteplay/WifiTuning.cpp`; incluir no probe
- [x] T031 [US3] `src/remoteplay/WifiTuningWin.cpp` (wlanapi.dll dinâmica) e compilar contra cabeçalhos Windows
- [x] T032 [US3] Ligar o `WifiTuning` em `RemotePlaySessionSource::run` com registro `remoteplay-wifi`

## Phase 5b: Achado da primeira crítica (perda falsa no relatório ao console)

- [x] T036 [US1] Testes `late_fec_packet_not_reported_lost` e `packet_stats_late_credit` (vermelhos antes do código)
- [x] T037 [US1] Crédito em `packetstats.c` (`chiaki_packet_stats_push_late_unit`, teto 64) e chamada em `avreorder.c` só para chegada em até 16 ms após pulo por correção de erros
- [x] T038 [US1] Sabotagens S9 a S11 (crédito nunca pedido, sem limite de 16 ms, não aplicado na conta) e patch 0006 regenerado
- [x] T039 [US1] Simulação mede a perda informada ao console de ponta a ponta (antiga x nova) e os descartes da fila cheia; S9 e S11 agora também ficam vermelhos nela

## Phase 6: Polish

- [x] T033 Crítico de contexto limpo sobre o diff completo, os testes e as alegações (aprovado, sem P0/P1)
- [x] T034 Consertar o que o crítico achar com evidência; rejulgar se grave (P3: travessão no painel trocado por hífen, spec do pacote duplicado, contrato sem função inexistente; lacuna declarada virou T036 a T038)
- [x] T035 Atualizar quickstart.md com os comandos e números reais; registrar no WORKLOG do Veyra o que foi e o que não foi verificado

## Dependencies & Execution Order

- Phase 2 depende de Phase 1; US1 depende de Phase 2.
- US2 (T023 em diante) depende de T018 (estatísticas publicadas); T021/T022 são independentes.
- US3 é independente de US1 e US2.
- Polish depende de todas.
