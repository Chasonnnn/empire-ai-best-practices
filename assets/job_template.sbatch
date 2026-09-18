#!/bin/bash
# Submit with explicit --account ACCOUNT --partition PARTITION and optional --qos QOS.
# From the project directory, export PROJECT_PYTHON (absolute), TRAIN_SCRIPT
# (absolute), and HF_HOME (approved cache path) before submission.
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --job-name=myjob
#SBATCH --output=slurm-%j.out
set -euo pipefail
: "${PROJECT_PYTHON:?Set the absolute project environment interpreter}"
: "${TRAIN_SCRIPT:?Set the absolute training script path}"
: "${HF_HOME:?Set the approved cache directory}"
[[ "$PROJECT_PYTHON" = /* && -x "$PROJECT_PYTHON" ]] || exit 2
[[ "$TRAIN_SCRIPT" = /* && -f "$TRAIN_SCRIPT" ]] || exit 2
[[ -d "$HF_HOME" && -w "$HF_HOME" ]] || exit 2
exec "$PROJECT_PYTHON" "$TRAIN_SCRIPT"
