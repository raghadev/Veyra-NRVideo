# Research: Baixa latência no PS5 Remote Play

> **Numeração dos patches (25/11/2026)**: este documento nasceu antes da junção com o Veyra 2.2.1. Hoje a fila é:
> 0001 a 0005 do Veyra (o 0005, novo no 2.2.1, é o buffer de recepção de 4 MiB), depois os nossos
> `0006-chiaki-reorder-queue-16bit-wrap`, `0007-chiaki-av-reorder` e `0008-chiaki-packet-stats-16bit-wrap`
> (antes 0005, 0006 e 0007). O nosso antigo 0008 (buffer de recepção) saiu: o do Veyra faz o mesmo.

Fontes lidas nesta sessão (2026-11-23). Commit fixado do chiaki-ng: `0e16950165f06e5c3291537c2eeba6e852be7120`
com os patches 0001 a 0004 do Veyra aplicados.

## R1. Onde a imagem espera por pacote perdido

- **Achado**: `lib/src/takion.c` define `TAKION_AV_REORDER_TIMEOUT_US 16000` e, em
  `takion_av_queue_flush_with_timeout`, quando o pacote da frente da fila de vídeo falta, segura todos os
  pacotes seguintes até 16 ms antes de pular. A espera não olha se o quadro já é reconstruível.
- **Consequência**: cada perda custa até 16 ms para aquele quadro e para os que estão atrás dele
  (bloqueio de cabeça de fila), mesmo quando a correção de erros resolveria na hora.
- **Decisão**: trocar a política de espera, mantendo a fila, o descarte e o despacho como estão.

## R2. A correção de erros aceita quaisquer k pacotes

- **Achado**: `lib/src/fec.c` usa `cauchy_original_coding_matrix` + `jerasure_matrix_decode` (Reed-Solomon
  de Cauchy): reconstrói com qualquer conjunto de `k` unidades de `n`, desde que as perdas sejam no máximo
  `m = n - k`. `chiaki_frame_processor_flush_possible` já usa exatamente
  `source_received + fec_received >= source_expected`, e o `videoreceiver.c` já libera o quadro assim que
  isso vale.
- **Decisão**: o critério "quadro reconstruível" na fila é o mesmo do frame processor: unidades únicas
  disponíveis (já entregues + na fila) `>= units_in_frame_total - units_in_frame_fec`.

## R3. Como saber a que quadro pertence um pacote que não chegou

- **Achado**: o próprio takion inicia a fila com `packet_index - unit_index` (primeiro pacote do quadro) e
  ordena por `packet_index`, o que só funciona se os índices forem contíguos dentro e entre quadros.
- **Decisão**: para uma lacuna `g`, o quadro dela é o de qualquer pacote conhecido `P` (na fila ou o último
  entregue) com `primeiro(P) <= g <= primeiro(P) + total(P) - 1`, em aritmética circular de 16 bits.
  Sem pacote conhecido do mesmo quadro, a lacuna é tratada como não reconstruível.
- **Alternativa descartada**: decidir só pelo `frame_index` dos vizinhos, porque erra quando a lacuna é
  a última unidade de um quadro e o vizinho seguinte já é do próximo quadro.

## R4. Espera adaptativa

- **Decisão**: janela vigente `window_us` com piso 2000 e teto 16000, começando no teto.
  - Atraso medido `now - inicio_da_lacuna`, tanto de pacote que preenche a lacuna a tempo quanto de pacote
    que chega depois de a lacuna ter sido pulada por tempo esgotado, alimenta um pico com meia-vida de
    1,5 s (calculado a partir do instante do pico, então não depende de quantas vezes a função roda);
    alvo `= clamp(pico * 3/2 + 1000)`; a janela sobe na hora até o alvo.
  - Chegada tardia de lacuna pulada pela correção de erros só conta estatística (não custou nada).
  - Descida limitada a 2 ms por segundo.
  - Do teto ao piso sem nenhuma reordenação: o alvo chega ao piso em cerca de 7 s e a descida limitada
    leva a janela ao piso em cerca de 8 s, dentro do limite de 10 s de SC-004.
- **Alternativa descartada**: janela fixa menor (por exemplo 4 ms), porque quebra redes Wi-Fi que
  reordenam mais e não se ajusta sozinha.

## R5. Wi-Fi sem varredura (documentação da Microsoft)

- **Achado** (learn.microsoft.com, páginas `wlan_intf_opcode`, `WlanSetInterface`, `WlanQueryInterface`):
  `wlan_intf_opcode_background_scan_enabled` e `wlan_intf_opcode_media_streaming_mode` recebem `BOOL`, só
  valem com a placa conectada, são por cliente ("disabled if at least one client disables it", "enabled
  if at least one client enables it") e voltam sozinhos ao padrão se a placa desconectar. A documentação
  não diz o que acontece quando o cliente fecha o handle ou o processo termina.
- **Decisão**: abrir handle próprio, ajustar só placas conectadas, e ao fim **desfazer explicitamente**
  (`background_scan_enabled = TRUE`, `media_streaming_mode = FALSE`) antes de `WlanCloseHandle`. A DLL é
  carregada em tempo de execução (`wlanapi.dll`), e qualquer falha só gera registro.
- **Limite declarado**: se o processo for morto à força, o que o Windows faz com o voto do cliente não
  está documentado; a placa volta ao padrão no próximo desconectar.

## R6. Onde ligar no Veyra

- Números da sessão: `ChiakiBackend::snapshot()` já lê `session.stream_connection.packet_stats`; o novo
  contador mora ao lado, em `ChiakiStreamConnection`, iniciado junto com ele (memória válida desde
  `chiaki_session_init`).
- Laço da sessão: `RemotePlaySessionSource::run` lê `nativeSnapshot()` uma vez por segundo; guarda o último
  valor para a tela.
- Estado do motor: `EngineController.cpp` (linha 1935) copia `rates()` para o snapshot; os números de rede
  entram no mesmo ponto.
- Tela: `qml/Veyra/StreamHud.qml` já mostra PC e Xbox com o atalho Ctrl+Alt+Shift+S (`Main.qml`); o PS5
  entra no mesmo componente, com o mesmo contrato de traço para valor ausente.

## R7. Onde dá para testar daqui (macOS)

- chiaki completo (fixado + 0001 a 0004) compila no Mac com Ninja e passa 102 de 102 testes munit.
- Testes portáveis do Veyra: `services/remoteplay-probe` (CMake, `VEYRA_RP_BUILD_NATIVE=OFF`) foi feito
  para rodar fora do Windows; recebe a lógica nova que não depende de Win32.
- Código só de Windows (Wi-Fi real, ponte Qt, QML): compilação contra cabeçalhos do Windows quando o
  compilador cruzado estiver disponível; execução só no notebook do usuário.

## R8. Relatório de perda ao console (achado depois da primeira crítica)

- **Achado**: `lib/src/congestioncontrol.c` lê `packet_stats` a cada 200 ms e manda ao PS5 "recebidos x
  perdidos" (limitado por `packet_loss_max`, 0,05 no Veyra). O `frameprocessor.c` conta como perdida toda
  unidade que faltava quando o quadro seguinte começou. Com o pulo pela correção de erros, um pacote só
  atrasado que chega depois do pulo é descartado pela fila e entrava como perda, coisa que a política
  antiga (que esperava 16 ms) não fazia.
- **Medido na simulação** (5% dos pacotes atrasados até 3 ms, sem perda): 4151 pacotes, 2,40% do total,
  chegaram depois de o quadro já ter sido refeito. Sem conserto, o console receberia ~2,4% de perda falsa.
- **Decisão**: crédito em `packet_stats` (`chiaki_packet_stats_push_late_unit`, no máximo 64 guardados),
  consumido na próxima contagem de quadro com perda; só para chegada em até 16 ms do momento da lacuna.
- **Medido de ponta a ponta** (a simulação conta por quadro como o `frameprocessor.c`): com reordenação de
  até 3 ms, antiga e nova informam 0 perdido; com 1% de perda real (1732 pacotes), a nova informa 1732 e a
  antiga 1737, porque a espera de 16 ms encheu a fila de 64 posições e jogou fora 5 pacotes bons.
- **Limite conhecido** (segundo crítico): com atrasos acima de 16 ms a nova pode informar um pouco mais que a
  antiga (+0,31 pp com atrasos até 20 ms); pacote duplicado depois de pulo por correção pode ser creditado
  duas vezes (no máximo 1 unidade por duplicata, teto 64). Ambos registrados, nenhum muda decisão.


## R9. Pesquisa funda de 23/11 (GitHub do chiaki-ng, Moonlight, FFmpeg, medições) e leitura do Veyra

**Piso que nenhum código do PC muda**
- O console limita o Remote Play a 1080p60 (mantenedor do chiaki-ng, issue 639: "sony caps the server
  running on the PS to 1080p"); ninguém relata 120 fps, 1440p ou 4K, nem no PS5 Pro.
- Atraso medido de ponta a ponta: PS Portal 66 a 83 ms atrás da TV (Digital Foundry, lido de segunda
  mão); chiaki-ng 1.10.0 cerca de 58 ms atrás do monitor ligado direto, e uma versão de desenvolvimento
  108 ms, filmado a 120 fps (issue 807). A diferença de 50 ms era só o jeito de mostrar o quadro.

**Hipóteses eliminadas com prova**
- Decodificador segurando quadro: não acontece. Cabeçalhos reais do PS5 (dos testes do chiaki, lidos com
  `ffmpeg -bsf:v trace_headers`): H.264 com `bitstream_restriction_flag=1`, `max_num_reorder_frames=0`,
  `pic_order_cnt_type=2`; HEVC com `sps_max_num_reorder_pics=0`. No FFmpeg atual `AV_CODEC_FLAG_LOW_DELAY`
  nem é lido pelos decodificadores h264 e hevc (só desliga frame threading), e aqui `thread_count=1`.
- Motor atrasando a exibição do stream: sem gerador de quadros o prazo é "assim que ficar pronto"
  (`EngineController.cpp`, `liveTimeline.resetPair(..., options.fg&&!fgHeld?pairDelay:0, ...)`). Com
  gerador por interpolação o atraso de um quadro de origem é inerente.

**Achados que viraram código**
- `SO_RCVBUF` do takion era a janela de dados anunciada, 100 kB (`TAKION_A_RWND 0x19000`), menor que um
  quadro grande; upstream discute o mesmo em PR 873 e 817 (não fundidos). Virou o nosso patch de buffer,
  retirado em 25/11/2026 porque o Veyra 2.2.1 trouxe o mesmo conserto como patch 0005 dele.
- `packetstats.c`: `seq_max - seq_min` de dois valores de 16 bits promovidos a int; o relatório da virada
  do índice de áudio (a cada ~655 s) dizia ~2^64 perdidos. O console reduz a taxa de vídeo quando ouve
  perda (PR 157, PR 871 fechado sem fundir). Gêmeo do defeito do patch da fila (hoje 0006), que a minha
  busca de gêmeos anterior não pegou porque só procurava somas. Patch de packet stats (hoje 0008).
- Mesma função, achado medido pelo crítico da segunda leva: a regra original
  `seq_received > seq_diff ? seq_diff : seq_diff - seq_received` dava o intervalo inteiro como perdido
  quando chegava um quadro atrasado (10 recebidos + 1 atrasado = 10 "perdidos"). Passou a ser zero perda
  quando chegam mais quadros do que o intervalo comporta. Também no patch de packet stats, com teste próprio.
- Laço dono da sessão dormia `sleep_for(1ms)` sem quadro pronto. Com o relógio do Windows afinado dura 1 a
  2 ms; sem afinar, até 15,6 ms (o próprio autor anotou isso no laço de só-controle e usou timer de alta
  resolução lá). O Qt 6.8 afina o relógio enquanto houver QTimer de até 20 ms ativo
  (`qeventdispatcher_win.cpp`: `timeSetEvent(interval, 1, ...)`), então o caso comum é 1 a 2 ms. Agora o
  laço espera na variável de condição da fila de vídeo.

**Candidatos não feitos (fase 2)**
- Painel: mostrar espera na fila e tempo de decodificação que o Veyra já mede (`ingressWaitMeanMs`,
  `decodeMeanMs`, `decodeP95Ms`) e o tempo chegada até exibição, para provar ganho no hardware real.
- Leitura do controle na interface a cada 8 ms no PS5 (Xbox e PC usam 4 ms).
- Evento de chegada para o motor (hoje ele confere a cada até 1 ms).
- Fora do código: Moonlight evita `SetMaximumFrameLatency(1)` com waitable porque o Present bloqueia no
  DWM; vale medir no Veyra com PresentMon antes de mexer. Saída em 120 Hz com VRR reduz a varredura.
- Controle pareado direto no PS5 durante o Remote Play: sem confirmação para PS5 (no PS4 o console
  fechava a sessão); é teste de 5 minutos em casa. Ganho estimado pequeno (5 a 10 ms).
