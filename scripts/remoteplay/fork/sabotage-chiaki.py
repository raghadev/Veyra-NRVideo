"""Mutation check for the fork's chiaki-ng patches (0006 to 0008).

Plants one defect at a time in a patched chiaki-ng stage, rebuilds, runs the munit suite and
restores the file byte for byte. Every defect must turn at least one test red; exit code 1
when one is not caught, when a snippet is not found or when the build breaks.

usage: python3 -I sabotage-chiaki.py <patched-stage-dir> <ninja-build-dir>

The build dir is a Ninja build of the stage configured with -DCHIAKI_ENABLE_TESTS=ON (see
specs/001-ps5-baixa-latencia/quickstart.md). Run verify-chiaki-stage.py afterwards: it proves
that the stage is back to the exact patched state. macOS/Linux developer tool, not part of the
product build. S14 and S15 belonged to the fork's old receive buffer patch, which Veyra 2.2.1
replaced with its own 0005 patch.
"""
import pathlib
import re
import subprocess
import sys

SABOTAGES = [
    ("S1 sem pulo por correcao de erros", "lib/src/avreorder.c",
     "\tif(!known || fec >= total)\n\t\treturn false;\n",
     "\tif(1 || !known || fec >= total)\n\t\treturn false;\n"),
    ("S2 faixa do quadro um a mais", "lib/src/avreorder.c",
     "(ChiakiSeqNum16)((ChiakiSeqNum16)seq_num - first) < total;",
     "(ChiakiSeqNum16)((ChiakiSeqNum16)seq_num - first) <= total;"),
    ("S3 janela nao sobe na chegada tardia", "lib/src/avreorder.c",
     "\t\t\treorder->stats.too_late_timeout++;\n\t\t\tobserve_late(reorder, now_us - skip->gap_start_us, now_us);\n",
     "\t\t\treorder->stats.too_late_timeout++;\n"),
    ("S4 janela nunca desce", "lib/src/avreorder.c",
     "\tif(!reorder->adaptive || now_us <= reorder->last_decay_us)\n\t\treturn;\n",
     "\tif(1 || !reorder->adaptive || now_us <= reorder->last_decay_us)\n\t\treturn;\n"),
    ("S5 modo antigo ignorado", "lib/src/avreorder.c",
     "\treorder->adaptive = adaptive;\n",
     "\treorder->adaptive = true; (void)adaptive;\n"),
    ("S6 virada de 16 bits sem truncar", "lib/src/reorderqueue.c",
     "return (uint64_t)(ChiakiSeqNum##bits)((ChiakiSeqNum##bits)a + (ChiakiSeqNum##bits)b);",
     "return (uint64_t)((ChiakiSeqNum##bits)a + (ChiakiSeqNum##bits)b);"),
    ("S7 chegada a tempo nao conta", "lib/src/avreorder.c",
     "\t\treorder->stats.late_fills++;\n\t\tobserve_late(reorder, now_us - reorder->head_wait_start_us, now_us);\n",
     "\t\t(void)0;\n"),
    ("S8 espera nao contabilizada", "lib/src/avreorder.c",
     "\treorder->stats.wait_us_total += (uint64_t)waited;\n",
     "\t(void)waited;\n"),
    ("S9 credito nunca pedido", "lib/src/avreorder.c",
     "\t\t\t\tchiaki_packet_stats_push_late_unit(reorder->box->packet_stats);\n",
     "\t\t\t\t(void)0;\n"),
    ("S10 credito sem limite de 16 ms", "lib/src/avreorder.c",
     "\t\t\tif(now_us - skip->gap_start_us <= CHIAKI_AV_REORDER_WINDOW_MAX_US && reorder->box && reorder->box->packet_stats)",
     "\t\t\tif(reorder->box && reorder->box->packet_stats)"),
    ("S11 credito nao aplicado na conta", "lib/src/packetstats.c",
     "\treceived += credit;\n\tlost -= credit;\n",
     "\t(void)credit;\n"),
    ("S12 relatorio de perda sem truncar 16 bits", "lib/src/packetstats.c",
     "\tuint64_t seq_diff = (ChiakiSeqNum16)(stats->seq_max - stats->seq_min);\n",
     "\tuint64_t seq_diff = stats->seq_max - stats->seq_min;\n"),
    ("S13 perda sequencial nao contada", "lib/src/packetstats.c",
     "\tuint64_t seq_lost = stats->seq_received >= seq_diff ? 0 : seq_diff - stats->seq_received;\n",
     "\tuint64_t seq_lost = 0; (void)seq_diff;\n"),
    ("S16 quadro atrasado vira perda total", "lib/src/packetstats.c",
     "\tuint64_t seq_lost = stats->seq_received >= seq_diff ? 0 : seq_diff - stats->seq_received;\n",
     "\tuint64_t seq_lost = stats->seq_received > seq_diff ? seq_diff : seq_diff - stats->seq_received;\n"),
]

if len(sys.argv) != 3:
    sys.exit(__doc__)
STAGE = pathlib.Path(sys.argv[1]).resolve()
BUILD = pathlib.Path(sys.argv[2]).resolve()
SUMMARY = re.compile(r"\d+ of \d+ \(\d+%\) tests successful")


def run(cmd):
    return subprocess.run(cmd, cwd=BUILD, capture_output=True, text=True, timeout=900)


failed_any = False
for name, rel, old, new in SABOTAGES:
    path = STAGE / rel
    original = path.read_bytes()  # bytes: the restore must not touch line endings
    if old.encode() not in original:
        print(f"{name}: TRECHO NAO ENCONTRADO (sabotagem invalida)")
        failed_any = True
        continue
    path.write_bytes(original.replace(old.encode(), new.encode()))
    try:
        build = run(["ninja"])
        if build.returncode != 0:
            print(f"{name}: BUILD FALHOU\n{build.stdout[-800:]}")
            failed_any = True
            continue
        test = run(["./test/chiaki-unit"])
        out = test.stdout + test.stderr
        red = sorted(set(re.findall(r"^(/chiaki/\S+?)\s*\[ ERROR \]", out, re.M)))
        summary = SUMMARY.findall(out)
        print(f"{name}: {'VERMELHO' if red else 'VERDE (sabotagem NAO detectada)'} {summary[-1] if summary else ''}")
        for test_name in red:
            print(f"    {test_name}")
        if not red:
            failed_any = True
    finally:
        path.write_bytes(original)
run(["ninja"])
test = run(["./test/chiaki-unit"])
restored = SUMMARY.findall(test.stdout + test.stderr)
print("RESTAURADO:", restored[-1] if restored else "SEM RESUMO (suite nao rodou)")
if not restored or test.returncode != 0:
    failed_any = True
sys.exit(1 if failed_any else 0)
