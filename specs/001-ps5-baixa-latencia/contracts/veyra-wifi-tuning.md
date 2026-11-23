# Contrato: ajuste de Wi-Fi da sessão PS5

## Lógica portável (include/veyra/remoteplay/WifiTuning.h, src/remoteplay/WifiTuning.cpp)

```cpp
struct WifiInterface { std::array<uint8_t,16> guid{}; bool connected=false; };
class WifiApi {                       // borda: real no Windows, falsa nos testes
public:
    virtual ~WifiApi() = default;
    virtual bool open(uint32_t& error) = 0;
    virtual std::vector<WifiInterface> interfaces(uint32_t& error) = 0;
    virtual uint32_t setBackgroundScan(const WifiInterface&, bool enabled) = 0;  // 0 = sucesso
    virtual uint32_t setMediaStreaming(const WifiInterface&, bool enabled) = 0;
    virtual void close() = 0;
};
enum class WifiTuningStatus { Applied, NoWifi, ApiUnavailable, Failed };
class WifiTuning {                    // RAII: construir aplica, destruir desfaz
public:
    explicit WifiTuning(std::unique_ptr<WifiApi> api);
    ~WifiTuning();                    // desfaz só o que deu certo, depois close(); nunca lança
    WifiTuningStatus status() const;
    unsigned adjustedCount() const;
    uint32_t lastError() const;
};
std::unique_ptr<WifiApi> makeSystemWifiApi();  // Windows: wlanapi.dll em tempo de execução; outros: nullptr
```

## Regras

1. Só placas `connected` recebem ajuste (a documentação exige placa conectada).
2. Ordem: desligar procura, ligar modo de transmissão. Cada sucesso é lembrado separadamente.
3. Desfazer em ordem inversa: modo de transmissão `FALSE`, procura `TRUE`, depois `close()`.
4. `open` falhando = `ApiUnavailable`; sem placa conectada = `NoWifi`; algum ajuste aplicado = `Applied`;
   nenhum aplicado com erro = `Failed` (com `lastError`).
5. Nenhum caminho lança exceção nem impede a sessão.

## Binding Windows (src/remoteplay/WifiTuningWin.cpp, só `_WIN32`)

`LoadLibraryExW(L"wlanapi.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32)`, `WlanOpenHandle(2, ...)`,
`WlanEnumInterfaces` (`isState == wlan_interface_state_connected`), `WlanSetInterface` com
`wlan_intf_opcode_background_scan_enabled` / `wlan_intf_opcode_media_streaming_mode` e `BOOL`,
`WlanFreeMemory`, `WlanCloseHandle`, `FreeLibrary`.

## Onde liga

`RemotePlaySessionSource::run`: um `WifiTuning` vivo durante cada tentativa de conexão; o resultado vai
para o registro `remoteplay-wifi`.
