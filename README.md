# AmpliconSuite offline: CRAM add-on

Add-on for the [ampliconsuite-offline](https://github.com/Tim-Yu/ampliconsuite-offline) bundle. Only needed when the
input alignments are **CRAM** rather than BAM.

## Why
CRAM files store no reference bases. To decode them, samtools/htslib needs every reference sequence named in the CRAM
header, looked up by MD5. AmpliconSuite-pipeline normally fetches missing sequences from ENA, which the controlled
environment cannot reach. The reference FASTA the CRAMs were aligned to *is* available locally there, so we build the
htslib checksum-addressed cache (`REF_CACHE`) from it once, with `seq_cache_populate.pl` shipped inside the image.
After that, CRAM decoding is fully offline. The AA data-repo FASTA alone is not sufficient for CRAMs aligned to a
reference with decoys/HLA/alt contigs; use the exact FASTA used for alignment.

## Use (controlled environment)
```bash
source /path/to/ampliconsuite/env_controlled.sh        # from the main bundle
# 1) build the cache once (~3 GB for GRCh38, a few minutes); optionally preflight a CRAM
bin/prepare_cram_cache.sh --fasta /path/GRCh38_reference.fasta --cache $AMPSUITE_ROOT/cram_ref_cache \
    --cram /path/sample.cram
#    (or as an LSF job: bsub -env "all,FASTA=/path/GRCh38_reference.fasta" < hpc/build_cram_cache.lsf)
# 2) tell the launcher where the cache is (add this line to env_controlled.sh to make it permanent)
export REF_CACHE="$AMPSUITE_ROOT/cram_ref_cache/%2s/%2s/%s"
# 3) run exactly as with a BAM
run_ampsuite.sh -s SAMPLE -t 16 --bam /path/sample.cram --ref GRCh38 --run_AA --run_AC -o /path/out
```
`run_ampsuite.sh` detects the `.cram` suffix, mounts the cache read-only at `/home/cram_cache` and sets
`REF_CACHE`/`REF_PATH` inside the container, so both samtools and CNVkit (pysam) decode from the cache.
Validated offline (network namespace) on the GBM39 test data: results byte-identical to the BAM run; CRAM decoding makes
the CNVkit and seed-filtering stages several times slower (15 min vs 4 min), so prefer BAMs when both exist.

## Fallback: convert CRAM to BAM
```bash
bin/cram_to_bam.sh --cram /path/sample.cram --fasta /path/GRCh38_reference.fasta --out /path/sample.bam --threads 8
```
This uses samtools 1.21 inside the image and needs roughly 1.5x the CRAM size in disk.

## Files
- `bin/prepare_cram_cache.sh`: builds the cache from a FASTA; `--cram` runs the upstream preflight (header MD5 lookup + decode one record).
- `bin/cram_to_bam.sh`: conversion fallback.
- `hpc/build_cram_cache.lsf`: LSF template for the cache build.

Same licences as the main bundle (see `LICENSES.md`). Research use only.
