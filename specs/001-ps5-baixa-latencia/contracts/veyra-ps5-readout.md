# Contrato: números do PS5 no Veyra

## `remoteplay::NativeSnapshot` (include/veyra/remoteplay/ChiakiBackend.h)

Campos novos, preenchidos em `ChiakiBackend::snapshot()` a partir de
`chiaki_stream_connection_av_reorder_stats`: `reorderValid`, `reorderAdaptive`, `reorderGaps`,
`reorderFecSkips`, `reorderTimeoutSkips`, `reorderLateFills`, `reorderTooLateTimeout`,
`reorderTooLateFec`, `reorderWaitUsTotal`, `reorderWaitUsMax`, `reorderWindowUs`.

## `remoteplay::NetworkReadout` (include/veyra/remoteplay/NetworkReadout.h, portável)

```cpp
struct NetworkCounters { // uma leitura
    bool valid=false, adaptive=false;
    uint64_t packetReceived=0, packetLost=0;            // janela do chiaki (pode zerar sozinha)
    uint64_t gaps=0, fecSkips=0, timeoutSkips=0, lateFills=0, tooLateTimeout=0, tooLateFec=0, waitUsTotal=0;
    uint32_t waitUsMax=0, windowUs=0;
};
struct NetworkReadout {  // o que o painel mostra; std::nullopt = traço
    std::optional<double> lossPercent, gapsPerSecond, fecSkipsPerSecond, timeoutSkipsPerSecond, waitMsPerSecond,
                          waitMaxMs, windowMs;
    uint64_t tooLateTimeout=0, tooLateFec=0;
    bool adaptive=false, valid=false;
};
NetworkReadout makeNetworkReadout(const NetworkCounters& now, const NetworkCounters* previous, double seconds);
```

Regras: sem `previous` ou `seconds <= 0` as taxas viram traço; contador que diminuiu (sessão nova) vira
traço naquela leitura; `lossPercent` é `lost / (received + lost)` da leitura atual e traço com zero
pacotes; `valid=false` deixa tudo traço.

## `RemotePlaySessionSource::network()`

Retorna o último `NetworkReadout` calculado no laço da sessão (uma vez por segundo), sob o mutex da fonte.

## Estado do motor e ponte

`EngineSnapshot.remoteNetwork` (tipo `NetworkReadout`) copiado junto com `rates()`. A ponte expõe
`Q_PROPERTY(QVariantMap ps5Stream READ ps5Stream NOTIFY snapshotChanged)` com chaves: `streaming`, `valid`,
`adaptive`, `receivedFps`, `decodedFps`, `lossPercent`, `gapsPerSecond`, `fecSkipsPerSecond`,
`timeoutSkipsPerSecond`, `waitMsPerSecond`, `waitMaxMs`, `windowMs`, `tooLateTimeout`, `tooLateFec`.
Valor ausente = chave com `-1` (o QML mostra traço para negativo).

## Painel (qml/Veyra/StreamHud.qml)

Linha do PS5 quando `veyra.ps5Stream.streaming`; o atalho Ctrl+Alt+Shift+S também fica ativo com PS5.
