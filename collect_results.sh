#!/usr/bin/env bash
# collect_results.sh - gathers the REAL results of your own run into my_results.txt
cd "$(dirname "$0")"
OUT=my_results.txt
{
echo "MY RESULTS - Digital Media Archive Management System - Chiamaka Ozurumba - $(date '+%Y-%m-%d %H:%M %Z')"
for P in 1 2 3 4 5; do
  F=$(ls -d portfolio-$P-*); L=$F/p${P}_output.log
  echo; echo "================ PORTFOLIO $P: $L ================"
  if [ -f "$L" ]; then wc -l < "$L" | sed 's/^/log lines: /'; if [ "$(wc -c < "$L")" -le 16000 ]; then cat "$L"; else head -c 9000 "$L"; echo "  ..."; tail -c 6000 "$L"; fi; else echo "(missing $L)"; fi
done
echo; echo "===== GitHub ====="; git remote get-url origin 2>&1; git log --oneline 2>&1 | head -12
} > "$OUT" 2>&1
echo "Saved $OUT"
