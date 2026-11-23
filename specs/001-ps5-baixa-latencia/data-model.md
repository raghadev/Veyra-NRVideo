# Data Model: Baixa latência no PS5 Remote Play

## chiaki: `ChiakiAvReorder` (estado da política de espera, só a linha do takion mexe)

| Campo | Tipo | Regra |
|---|---|---|
| `adaptive` | bool | false = comportamento antigo (16 ms fixos, sem pulo por correção de erros) |
| `head_wait_start_us` | int64 | 0 = cabeça presente; senão, quando a lacuna atual foi notada |
| `head_wait_seq_num` | uint64 | índice da lacuna atual |
| `head_wait_frame_known` | bool | se a lacuna já foi associada a um quadro |
| `dispatch_frame_first` | uint16 | primeiro índice do último quadro entregue |
| `dispatch_frame_total`, `dispatch_frame_fec` | uint16 | do último quadro entregue |
| `dispatch_frame_units` | uint16 | unidades únicas desse quadro já entregues |
| `have_dispatch` | bool | já entregou algum pacote |
| `window_us` | uint32 | espera vigente; piso 2000, teto 16000, início 16000 |
| `peak_us` | uint32 | pico de atraso observado, meia-vida 1,5 s; início 16000 |
| `last_decay_us` | int64 | última aplicação de decaimento |
| `skipped[16]` | anel | faixas puladas `{first, count, reason, at_us, gap_start_us}` para classificar chegada tardia |
| `stats` | `ChiakiAvReorderStats` | contadores abaixo |

Transições da lacuna: `presente -> faltando (notada)`; `faltando -> preenchida` (pacote chegou dentro da
janela); `faltando -> pulada_fec` (quadro reconstruível); `faltando -> pulada_tempo` (janela esgotou).

## chiaki: `ChiakiAvReorderStats` (cópia publicada, protegida por mutex)

| Campo | Significado |
|---|---|
| `gaps` | lacunas notadas |
| `fec_skips` | lacunas puladas na hora porque o quadro era reconstruível |
| `timeout_skips` | lacunas puladas por tempo esgotado |
| `late_fills` | pacotes que chegaram atrasados mas a tempo |
| `too_late_timeout` | pacotes que chegaram depois de pulados por tempo (custaram um quadro) |
| `too_late_fec` | pacotes que chegaram depois de pulados pela correção (não custaram nada) |
| `wait_us_total` | soma do tempo que a cabeça da fila ficou esperando |
| `wait_us_max` | maior espera única |
| `window_us` | espera vigente no momento da cópia |
| `adaptive` | se a política nova está ligada |

## chiaki: `ChiakiAvReorderStatsBox`

`{ ChiakiMutex mutex; ChiakiAvReorderStats stats; ChiakiPacketStats *packet_stats; }`, membro de
`ChiakiStreamConnection`, iniciado em `chiaki_stream_connection_init` (que aponta `packet_stats` para o
da conexão) e liberado no `fini`. O takion recebe um ponteiro (pode ser NULL) pela `ChiakiTakionConnectInfo`.

## chiaki: `ChiakiPacketStats.gen_late_credit`

Unidades contadas como perdidas que chegaram atrasadas (reordenadas). Cada contagem de quadro com perda
consome o crédito (perda menor, recebidos maior, nunca negativo). Teto de 64. Zera só no `init`.

## Veyra: `remoteplay::NativeSnapshot` (campos novos)

`reorderGaps, reorderFecSkips, reorderTimeoutSkips, reorderLateFills, reorderTooLateTimeout,
reorderTooLateFec, reorderWaitUsTotal` (uint64), `reorderWaitUsMax, reorderWindowUs` (uint32),
`reorderAdaptive` (bool), `reorderValid` (bool: false quando a sessão ainda não existe).

## Veyra: `remoteplay::NetworkReadout` (o que o painel mostra, calculado entre duas leituras)

| Campo | Regra de traço |
|---|---|
| `lossPercent` | traço sem pacotes na janela |
| `gapsPerSecond`, `fecSkipsPerSecond`, `timeoutSkipsPerSecond` | traço sem leitura anterior |
| `waitMsPerSecond` | traço sem leitura anterior |
| `waitMaxMs`, `windowMs` | traço se `reorderValid` falso |
| `tooLateTimeout`, `tooLateFec` | contagem acumulada da sessão |
| `adaptive` | texto "adaptativa" ou "fixa 16 ms" |

Contadores do chiaki que diminuem entre duas leituras (sessão reiniciada) zeram a referência em vez de
gerar número negativo.

## Veyra: `remoteplay::WifiTuning` (ajuste de Wi-Fi da sessão)

| Campo | Regra |
|---|---|
| `adjusted` | lista de GUIDs de placas em que algo foi ligado/desligado com sucesso |
| por placa: `scanDisabled`, `streamingEnabled` | só o que deu certo é desfeito |
| `status` | `Applied`, `NoWifi`, `ApiUnavailable`, `Failed` (com código) |

Ciclo: construir = aplicar; destruir = desfazer na ordem inversa e fechar o handle. Nunca lança exceção.
