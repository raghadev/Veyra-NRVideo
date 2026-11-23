# Implementation Plan: Baixa latência no PS5 Remote Play

**Branch**: `baixa-latencia-ps5` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-ps5-baixa-latencia/spec.md`

## Summary

A fila de vídeo do chiaki-ng segura a imagem até 16 ms a cada pacote perdido, mesmo quando o quadro já é
reconstruível pela correção de erros. A feature troca essa política por uma que (1) pula na hora a lacuna
de quadro reconstruível e (2) espera, nos outros casos, um tempo medido ao vivo entre 2 e 16 ms. A política
mora num módulo C novo e testável (`avreorder`), entra no Veyra como patch 0005, publica contadores que o
Veyra mostra num painel PS5 novo, e o Veyra ainda pede ao Windows que a placa Wi-Fi não faça varredura
durante a sessão.

## Technical Context

**Language/Version**: C11 compatível com MSVC (chiaki-ng); C++20 (Veyra); QML (Qt 6.8)

**Primary Dependencies**: chiaki-ng fixado em `0e16950` + patches 0001 a 0004; jerasure; munit; Qt 6;
`wlanapi.dll` (carregada em tempo de execução)

**Storage**: N/A

**Testing**: munit (`test/chiaki-unit`) no Mac; `services/remoteplay-probe` (CTest) no Mac para a lógica
portável do Veyra; compilação cruzada para Windows quando disponível; hardware real só no notebook

**Target Platform**: Windows 10/11 x64 (produto); macOS/Linux para os testes portáveis

**Project Type**: desktop-app (Veyra) com biblioteca C embutida (chiaki-ng)

**Performance Goals**: retenção extra por perda recuperável < 1 ms em simulação (antes ~16 ms);
custo por pacote limitado a varrer a fila (no máximo 64 entradas) só quando há lacuna

**Constraints**: sem VLA; sem alocação no caminho por pacote; patch aplicado depois de 0001 a 0004; HUD com
traço para valor ausente; atualização da UI dentro das cadências já decididas (33 ms / 250 ms)

**Scale/Scope**: 1 módulo C novo + ajustes em `takion.c`/`takion.h`/`streamconnection.*`; 3 a 4 arquivos
novos no Veyra + ajustes em ChiakiBackend, RemotePlaySessionSource, EngineController, ponte e HUD

## Constitution Check

| Princípio | Como o plano cumpre | Situação |
|---|---|---|
| I Medido, não prometido | Simulação mede antigo e novo no mesmo teste; painel mostra só número medido; relatório separa simulação de hardware | OK |
| II Patch mínimo e rastreável | Patch `0005-chiaki-av-reorder.patch` gerado contra o stage 0001 a 0004; verificador e lock atualizados; constante para voltar ao antigo | OK |
| III Teste com sabotagem | Teste de cada regra antes do código; sabotagem planejada por regra (tarefas T0xx) | OK |
| IV Nunca pior onde dá para saber | Pulo só com quadro reconstruível; janela com piso/teto e subida imediata; chegadas tardias contadas | OK |
| V Windows primeiro, falha segura | `WifiTuning` RAII com DLL dinâmica, desfaz explícito, nunca lança | OK |

Re-checagem depois do desenho (Phase 1): sem violação; nada em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-ps5-baixa-latencia/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── chiaki-avreorder.md
│   ├── veyra-ps5-readout.md
│   └── veyra-wifi-tuning.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/remoteplay/
├── patches/0005-chiaki-av-reorder.patch      # novo: avreorder.{h,c}, takion, streamconnection, testes
├── dependency-lock.json                      # + entrada do patch 0005
└── verify-chiaki-stage.py                    # + 0005 na lista

include/veyra/remoteplay/
├── ChiakiBackend.h                           # NativeSnapshot ganha campos reorder*
├── NetworkReadout.h                          # novo, portável
└── WifiTuning.h                              # novo, portável
src/remoteplay/
├── ChiakiBackend.cpp                         # lê as estatísticas do chiaki
├── NetworkReadout.cpp                        # novo
├── WifiTuning.cpp                            # novo (lógica)
└── WifiTuningWin.cpp                         # novo (binding Windows)
src/source/RemotePlaySessionSource.cpp        # guarda o readout; liga o WifiTuning
include/veyra/source/RemotePlaySessionSource.h
include/veyra/engine/EngineController.h       # remoteNetwork no snapshot
src/engine/EngineController.cpp
include/veyra/ui/QmlPlayerBridge.h            # ps5Stream
src/ui/bridge/RemotePlay.cpp
qml/Veyra/StreamHud.qml, qml/Veyra/Main.qml
services/remoteplay-probe/CMakeLists.txt      # compila NetworkReadout/WifiTuning nos testes
tests/remoteplay/CoreTests.cpp                # testes novos
CMakeLists.txt / cmake/VeyraRemotePlay.cmake  # arquivos novos no produto
```

**Structure Decision**: seguir a divisão existente do Veyra (lógica portável em `src/remoteplay`, testada
pelo probe; Win32 e Qt nas camadas de fonte, motor e UI). No chiaki, um módulo próprio para a política,
porque o takion mistura socket e thread e não dá para testar a decisão de espera dentro dele.

## Complexity Tracking

Nenhuma violação a justificar.
