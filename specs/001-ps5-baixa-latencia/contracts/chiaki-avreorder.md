# Contrato: API `chiaki/avreorder.h` (patch `0007-chiaki-av-reorder.patch` sobre o chiaki-ng)

Política de espera da fila de vídeo do takion, separada do socket para poder ser testada sozinha.

```c
#define CHIAKI_AV_REORDER_WINDOW_MIN_US 2000
#define CHIAKI_AV_REORDER_WINDOW_MAX_US 16000
#ifndef CHIAKI_AV_REORDER_ADAPTIVE_DEFAULT
#define CHIAKI_AV_REORDER_ADAPTIVE_DEFAULT 1   /* 0 = comportamento antigo (FR-006) */
#endif

typedef struct chiaki_av_reorder_unit_t {     /* campos do pacote que a política lê */
	ChiakiSeqNum16 packet_index;
	ChiakiSeqNum16 frame_index;
	uint16_t unit_index;
	uint16_t units_total;                     /* dados + correção */
	uint16_t units_fec;
} ChiakiAvReorderUnit;

typedef bool (*ChiakiAvReorderUnitOf)(void *entry, ChiakiAvReorderUnit *out);
typedef void (*ChiakiAvReorderDispatch)(uint64_t seq_num, void *entry, void *user); /* assume o entry */

typedef struct chiaki_av_reorder_stats_t { /* ver data-model.md */ } ChiakiAvReorderStats;
typedef struct chiaki_av_reorder_stats_box_t { ChiakiMutex mutex; ChiakiAvReorderStats stats; ChiakiPacketStats *packet_stats; } ChiakiAvReorderStatsBox;
typedef struct chiaki_av_reorder_t { /* estado privado, ver data-model.md */ } ChiakiAvReorder;

CHIAKI_EXPORT void chiaki_av_reorder_init(ChiakiAvReorder *r, bool adaptive, ChiakiAvReorderStatsBox *box);
CHIAKI_EXPORT void chiaki_av_reorder_on_arrival(ChiakiAvReorder *r, ChiakiReorderQueue *q, uint64_t seq_num, int64_t now_us);
CHIAKI_EXPORT void chiaki_av_reorder_flush(ChiakiAvReorder *r, ChiakiReorderQueue *q, int64_t now_us,
		ChiakiAvReorderUnitOf unit_of, ChiakiAvReorderDispatch dispatch, void *user);
CHIAKI_EXPORT int64_t chiaki_av_reorder_next_timeout_us(ChiakiAvReorder *r, int64_t now_us); /* -1 = nada pendente */
CHIAKI_EXPORT ChiakiErrorCode chiaki_av_reorder_stats_box_init(ChiakiAvReorderStatsBox *box);
CHIAKI_EXPORT void chiaki_av_reorder_stats_box_fini(ChiakiAvReorderStatsBox *box);
CHIAKI_EXPORT void chiaki_av_reorder_stats_get(ChiakiAvReorderStatsBox *box, ChiakiAvReorderStats *out);
CHIAKI_EXPORT void chiaki_stream_connection_av_reorder_stats(ChiakiStreamConnection *sc, ChiakiAvReorderStats *out);
/* packetstats.h: unidade contada como perdida que chegou atrasada vira crédito de "recebida" (até 64) */
CHIAKI_EXPORT void chiaki_packet_stats_push_late_unit(ChiakiPacketStats *stats);
```

## Garantias

1. `on_arrival` é chamada antes de `chiaki_reorder_queue_push` para todo pacote de vídeo; ela só observa
   (classifica preenchimento a tempo ou chegada tardia) e nunca mexe na fila.
2. `flush` entrega, em ordem, tudo o que puder; pula uma lacuna na hora se o quadro dela for reconstruível
   (`adaptive`), senão espera `window_us` a partir do momento em que a lacuna foi notada.
3. `flush` nunca libera nem perde um entry: todo entry sai pelo `dispatch` ou fica na fila (o descarte
   por fila cheia continua sendo do `drop_cb` da fila, como hoje).
4. Com `adaptive = false`, a decisão de pular é idêntica à antiga (16 ms fixos), e os contadores seguem
   funcionando para comparação.
5. Estatísticas: escritas só pela linha do takion; lidas por qualquer linha via `stats_get` (mutex).
6. Sem VLA, sem alocação dinâmica no caminho por pacote, laços limitados pelo tamanho da fila.
7. Pacote atrasado de lacuna pulada pela correção de erros, chegando em até 16 ms: crédito no
   `packet_stats` da conexão (FR-013), para o relatório de perda ao console ficar igual ao antigo.
