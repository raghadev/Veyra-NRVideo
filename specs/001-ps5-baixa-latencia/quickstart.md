# Quickstart: validar a baixa latência do PS5

## 1. No Mac (ou Linux): chiaki com os 8 patches (5 do Veyra 2.2.1 + 3 nossos)

```bash
git clone https://github.com/chiaki-ng/chiaki-ng.git chiaki-ng
cd chiaki-ng && git checkout 0e16950165f06e5c3291537c2eeba6e852be7120
for p in ../veyra/scripts/remoteplay/patches/000*.patch; do git apply "$p"; done
git submodule update --init --depth 1 test/munit third-party/nanopb third-party/jerasure third-party/gf-complete
cmake -S . -B build -G Ninja -DCHIAKI_ENABLE_GUI=OFF -DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_ENABLE_TESTS=ON \
  -DCHIAKI_ENABLE_FFMPEG_DECODER=OFF -DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF -DCHIAKI_ENABLE_SETSU=OFF \
  -DCHIAKI_ENABLE_SPEEX=OFF -DCHIAKI_ENABLE_STEAM_SHORTCUT=OFF -DCHIAKI_USE_SYSTEM_CURL=ON
cmake --build build && ./build/test/chiaki-unit
```

Esperado (medido em 2026-11-25, macOS): `122 of 122 (100%) tests successful` (102 do chiaki + 20 nossos). Com
`CHIAKI_TEST_REPORT=1 ./build/test/chiaki-unit --show-stderr /chiaki/avreorder/sim`:

```text
loss 1%: lost=1732 legacy extra/loss=12921 us adaptive extra/loss=0 us delivered legacy=3600 adaptive=3600 ...
loss 1%: reported to the console legacy=1737 adaptive=1732 (true loss 1732) queue drops legacy=5 adaptive=0
reorder 5% up to 3 ms: delivered=3600 of 3600 fec_skips=4025 timeout_skips=0 extra/frame=0 us late-after-fec=4151 (2.40% ...)
reorder 5% up to 3 ms: reported to the console legacy=0 adaptive=0
```

O buffer de recepção de 4 MiB agora vem do patch 0005 do próprio Veyra; o teste dele
(`veyra_remoteplay_udp_buffer_tests`) só compila no Windows e roda dentro do `build-native.ps1`.

No macOS, `-DPYTHON_EXECUTABLE` precisa apontar para um Python com `protobuf` e `grpcio-tools` (gerador
do nanopb), e `-DCMAKE_PREFIX_PATH` para curl e OpenSSL do Homebrew.

## 2. No Mac (ou Linux): partes portáveis do Veyra

```bash
cmake -S services/remoteplay-probe -B out/rp -G Ninja -DVEYRA_RP_BUILD_NATIVE=OFF
cmake --build out/rp && ctest --test-dir out/rp --output-on-failure
```

Esperado: `95 tests passed`. No clang do macOS o código antigo do Veyra não compila com `-Werror`; acrescente
`"-DCMAKE_CXX_FLAGS=-Wno-error=missing-field-initializers -Wno-error=implicit-int-float-conversion -Wno-error=sign-conversion"`
ao primeiro comando (no MSVC do produto não é preciso).

## 3. No notebook Windows (o teste que importa)

1. Compilar o Veyra pelo fluxo normal dele (`scripts/remoteplay/build-native.ps1`); o verificador de stage
   precisa imprimir `CHIAKI_STAGE_EXACT_PATCHES_VERIFIED`.
2. Abrir uma sessão PS5, apertar Ctrl+Alt+Shift+S e jogar 5 minutos no Wi-Fi.
3. Anotar no painel: perdas resolvidas na hora, esperas por tempo esgotado, espera por segundo, espera
   vigente; e no registro, as linhas `remoteplay-wifi`, `remoteplay-reorder` e `remoteplay-progress`
   (esta já traz a espera na fila e o tempo de decodificação medidos pelo Veyra).
4. Repetir com o build compilado com `CHIAKI_AV_REORDER_ADAPTIVE_DEFAULT=0` (comportamento antigo) para
   comparar a "espera por segundo" nas mesmas condições.
