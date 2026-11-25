"""Mutation check for the fork's portable Veyra code (PS5 readout, Wi-Fi tuning, video wait).

Plants one defect at a time in the Veyra sources, rebuilds the portable probe, runs its tests
and restores the file byte for byte. Every defect must be caught, by a red test or by the
compiler; exit code 1 when one is not caught or a snippet is not found.

usage: python3 -I sabotage-veyra.py <veyra-root> <probe-build-dir>

The build dir is a build of services/remoteplay-probe with -DVEYRA_RP_BUILD_NATIVE=OFF (see
specs/001-ps5-baixa-latencia/quickstart.md). macOS/Linux developer tool, not part of the
product build.
"""
import pathlib
import re
import subprocess
import sys

SABOTAGES = [
    ("V1 readout ignora valid", "src/remoteplay/NetworkReadout.cpp",
     "    if(!now.valid)return out;\n", ""),
    ("V2 perda sem pacotes divide por zero", "src/remoteplay/NetworkReadout.cpp",
     "    if(packets>0)out.lossPercent=", "    out.lossPercent="),
    ("V3 taxa sem tempo", "src/remoteplay/NetworkReadout.cpp",
     "if(!previous||!previous->valid||!(seconds>0))return out;", "if(!previous)return out;"),
    ("V4 contador que desce vira taxa", "src/remoteplay/NetworkReadout.cpp",
     "        return out; // counters restarted: a new session, no rate for this reading\n", "        {}\n"),
    ("V5 wifi mexe em placa desconectada", "src/remoteplay/WifiTuning.cpp",
     "            if(!iface.connected)continue;", "            if(false)continue;"),
    ("V6 wifi desfaz o que falhou", "src/remoteplay/WifiTuning.cpp",
     "        if(it->scanDisabled)try{", "        if(true)try{"),
    ("V7 wifi destrutor sem protecao", "src/remoteplay/WifiTuning.cpp",
     "        if(it->streamingEnabled)try{(void)api_->setMediaStreaming(it->iface,false);}catch(...){}",
     "        if(it->streamingEnabled){(void)api_->setMediaStreaming(it->iface,false);}"),
    ("V8 wifi registra so depois das duas chamadas", "src/remoteplay/WifiTuning.cpp",
     "            adjusted_.push_back({iface});\n            if(const auto e=api_->setBackgroundScan(iface,false))lastError_=e;else adjusted_.back().scanDisabled=true;\n            if(const auto e=api_->setMediaStreaming(iface,true))lastError_=e;else adjusted_.back().streamingEnabled=true;\n",
     "            Adjusted a{iface};\n            if(const auto e=api_->setBackgroundScan(iface,false))lastError_=e;else a.scanDisabled=true;\n            if(const auto e=api_->setMediaStreaming(iface,true))lastError_=e;else a.streamingEnabled=true;\n            adjusted_.push_back(a);\n"),
    ("V9 espera ignora quadro que chegou", "src/remoteplay/SessionInbox.cpp",
     "    if(video.waitForData(timeout))return VideoWait::Data;\n", "    (void)video.waitForData(timeout);\n"),
    ("V10 fechado vira tempo esgotado", "src/remoteplay/SessionInbox.cpp",
     "    return video.closed()?VideoWait::Closed:VideoWait::Timeout;\n", "    return VideoWait::Timeout;\n"),
    ("V11 espera segurando o cadeado da caixa", "src/remoteplay/SessionInbox.cpp",
     "    auto& video=shared_->video;\n", "    auto& video=shared_->video;std::lock_guard held(shared_->mutex);\n"),
    ("V12 espera nao espera", "src/remoteplay/SessionInbox.cpp",
     "    if(video.waitForData(timeout))return VideoWait::Data;\n",
     "    if(video.waitForData(timeout/1000))return VideoWait::Data;\n"),
]

if len(sys.argv) != 3:
    sys.exit(__doc__)
ROOT = pathlib.Path(sys.argv[1]).resolve()
BUILD = pathlib.Path(sys.argv[2]).resolve()
TOTAL = re.compile(r"TOTAL \d+ PASS \d+ FAIL \d+")


def run(cmd):
    return subprocess.run(cmd, cwd=BUILD, capture_output=True, text=True, timeout=900)


bad = False
for name, rel, old, new in SABOTAGES:
    path = ROOT / rel
    original = path.read_bytes()  # bytes: the restore must not touch line endings
    if old.encode() not in original:
        print(f"{name}: TRECHO NAO ENCONTRADO")
        bad = True
        continue
    path.write_bytes(original.replace(old.encode(), new.encode(), 1))
    try:
        build = run(["cmake", "--build", "."])
        if build.returncode != 0:
            print(f"{name}: VERMELHO (o compilador recusou)\n{build.stdout[-400:]}")
            continue
        test = run(["./veyra_remoteplay_core_tests"])
        out = test.stdout + test.stderr
        fails = sorted(set(re.findall(r"^FAIL (\S+?):", out, re.M)))
        crashed = test.returncode not in (0, 1)
        total = TOTAL.findall(out)
        if fails or crashed:
            print(f"{name}: VERMELHO {total[-1] if total else '(processo abortou, codigo %d)' % test.returncode}")
            for fail in fails:
                print(f"    {fail}")
        else:
            print(f"{name}: VERDE (NAO detectado) {total[-1] if total else ''}")
            bad = True
    finally:
        path.write_bytes(original)
run(["cmake", "--build", "."])
test = run(["./veyra_remoteplay_core_tests"])
restored = TOTAL.findall(test.stdout)
print("RESTAURADO:", restored[-1] if restored else "SEM RESUMO (testes nao rodaram)")
if not restored or test.returncode != 0:
    bad = True
sys.exit(1 if bad else 0)
