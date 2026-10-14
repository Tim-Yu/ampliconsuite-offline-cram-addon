#!/usr/bin/env bash
# cram_to_bam.sh - fallback for CRAM inputs: convert to BAM with the samtools (1.21) inside the AmpliconSuite image,
# using the LOCAL reference FASTA the CRAM was aligned to (no network). Produces <out>.bam + .bai.
#   cram_to_bam.sh --cram in.cram --fasta ref.fa --out out.bam [--threads 8] [--sif image.sif]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIF="${AMPSUITE_SIF:-}"; CRAM=""; FASTA=""; OUT=""; THREADS=8
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cram) CRAM="$2"; shift 2 ;; --fasta) FASTA="$2"; shift 2 ;; --out) OUT="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;; --sif) SIF="$2"; shift 2 ;;
    -h|--help) awk 'NR>1 { if (/^#/) { sub(/^# ?/,""); print } else exit }' "$0"; exit 0 ;; *) echo "unknown option $1" >&2; exit 1 ;;
  esac
done
[[ -n "$SIF" ]] || SIF="$(ls -1 "$SCRIPT_DIR"/../sif/*.sif 2>/dev/null | head -1 || true)"
[[ -f "$SIF" && -f "$CRAM" && -f "$FASTA" && -n "$OUT" ]] || { echo "need --sif/--cram/--fasta/--out" >&2; exit 1; }
CRAM="$(realpath "$CRAM")"; FASTA="$(realpath "$FASTA")"; mkdir -p "$(dirname "$OUT")"; OUT="$(realpath -m "$OUT")"
singularity exec --cleanenv --no-home \
  --bind "$(dirname "$CRAM"):/in:ro" --bind "$(dirname "$FASTA"):/ref:ro" --bind "$(dirname "$OUT"):/out" "$SIF" \
  bash -c "samtools view -@ $THREADS -b -T /ref/$(basename "$FASTA") -o /out/$(basename "$OUT") /in/$(basename "$CRAM") && samtools index -@ $THREADS /out/$(basename "$OUT")"
echo "wrote $OUT (+ .bai)"
