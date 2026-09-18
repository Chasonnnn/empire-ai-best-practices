#!/bin/bash
# Submit a BERT/SST-2 GPU smoke job using an existing locked project environment.
# This script does not install packages, delete previous runs, or wait for completion.
# Legacy submitter: one untyped GPU can be routed to a different partition/model.
# It has no hold/readback or physical placement gate; use a guarded project executor
# for a hardware-bound approval. See ../references/placement.md.
set -euo pipefail
printf '%s\n' 'WARNING: this legacy helper requests one untyped GPU; site policy may override SLURM_PARTITION and GPU identity. It performs no placement verification. Use a guarded executor for hardware-bound approval.' >&2
: "${SLURM_ACCOUNT:?Set the selected project account}"
: "${SLURM_PARTITION:?Set the selected GPU partition independently}"
: "${LUSTRE_ROOT:?Set the approved writable storage root}"
: "${SMOKE_PYTHON:?Set the absolute interpreter from the prepared project environment}"
: "${SMOKE_LOCKFILE:?Set the environment lockfile used to prepare that interpreter}"
: "${MODEL_REVISION:?Set an immutable bert-base-uncased commit revision}"
: "${DATASET_REVISION:?Set an immutable nyu-mll/glue commit revision}"
: "${SMOKE_MIN_ACCURACY:?Set the acceptance threshold for this workload}"
[[ "$LUSTRE_ROOT" = /* && -d "$LUSTRE_ROOT" && -w "$LUSTRE_ROOT" ]] || exit 2
[[ "$SMOKE_PYTHON" = /* && -x "$SMOKE_PYTHON" ]] || exit 2
[[ -f "$SMOKE_LOCKFILE" ]] || exit 2
[[ "$MODEL_REVISION" =~ ^[0-9a-fA-F]{40}$ && "$DATASET_REVISION" =~ ^[0-9a-fA-F]{40}$ ]] || exit 2
command -v sbatch >/dev/null
# Check the declared environment and input contract without performing training.
"$SMOKE_PYTHON" - <<'PY'
import math, os
import torch, transformers, datasets, accelerate
value = float(os.environ['SMOKE_MIN_ACCURACY'])
if not math.isfinite(value) or not 0 <= value <= 1:
    raise ValueError('invalid accuracy threshold')
PY
asset_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$LUSTRE_ROOT/smoke-runs"
run_dir=$(mktemp -d "$LUSTRE_ROOT/smoke-runs/run.XXXXXXXX")
cp "$asset_dir/train_smoke.py" "$run_dir/train.py"
cp "$SMOKE_LOCKFILE" "$run_dir/environment.lock"
mkdir -p "$run_dir/output" "$LUSTRE_ROOT/hf"
export HF_HOME="$LUSTRE_ROOT/hf" SMOKE_OUT="$run_dir/output"
export MODEL_REVISION DATASET_REVISION SMOKE_MIN_ACCURACY
# Capture actual environment alongside the declared lock; a copy alone is not proof of sync.
"$SMOKE_PYTHON" - "$run_dir" <<'PY'
import hashlib, importlib.metadata, json, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
manifest = {'python': sys.version, 'interpreter': sys.executable,
 'account': os.environ['SLURM_ACCOUNT'], 'partition': os.environ['SLURM_PARTITION'],
 'qos': os.environ.get('SLURM_QOS'), 'model_revision': os.environ['MODEL_REVISION'],
 'dataset_revision': os.environ['DATASET_REVISION'], 'min_accuracy': os.environ['SMOKE_MIN_ACCURACY'],
 'sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'train.py', root/'environment.lock')},
 'packages': sorted((d.metadata['Name'], d.version) for d in importlib.metadata.distributions())}
(root/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
PY
{
  printf '#!/bin/bash\nset -euo pipefail\n'
  printf 'export HF_HOME=%q SMOKE_OUT=%q MODEL_REVISION=%q DATASET_REVISION=%q SMOKE_MIN_ACCURACY=%q\n' "$HF_HOME" "$SMOKE_OUT" "$MODEL_REVISION" "$DATASET_REVISION" "$SMOKE_MIN_ACCURACY"
  printf 'exec %q %q\n' "$SMOKE_PYTHON" "$run_dir/train.py"
} > "$run_dir/job.sbatch"
args=(--parsable --account "$SLURM_ACCOUNT" --partition "$SLURM_PARTITION"
      --gres=gpu:1 --cpus-per-task=8 --mem=32G --time=00:30:00
      --job-name=bert_smoke --output "$run_dir/slurm-%j.out")
if [[ -n "${SLURM_QOS:-}" ]]; then args+=(--qos "$SLURM_QOS"); fi
# No automatic retry: a failed response can still leave a submitted external job.
if ! job=$(sbatch "${args[@]}" "$run_dir/job.sbatch"); then
  printf 'Submission unresolved; reconcile scheduler state before retrying. Run: %s\n' "$run_dir" >&2
  exit 1
fi
if [[ ! "$job" =~ ^[0-9]+(\;[a-zA-Z0-9._-]+)?$ ]]; then
  printf 'Submission response has no valid job ID; reconcile scheduler state. Run: %s\n' "$run_dir" >&2
  exit 1
fi
printf '%s\n' "$job" > "$run_dir/job-id.txt"
printf 'SUBMITTED %s\nRUN_DIR %s\nVerification pending: scheduler exit 0:0 and output/result.json must both pass. Physical GPU placement remains unverified by this helper.\n' "$job" "$run_dir"
