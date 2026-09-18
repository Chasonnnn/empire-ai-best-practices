#!/bin/bash
# Beta (NVL72) template: containers only, 4 GPUs per node minimum, SIGTERM checkpointing.
# Submit with explicit --account ACCOUNT and --qos QOS. Export TRAIN_SCRIPT (absolute, on a
# path visible inside the container) before submission. --requeue is opt-in: add it on the
# command line only when a silent restart is acceptable for this run's provenance.
#SBATCH --partition=beta
#SBATCH --nodes=1
#SBATCH --gres=gpu:4
#SBATCH --time=12:00:00
#SBATCH --signal=B:SIGTERM@900
#SBATCH --no-requeue
#SBATCH --job-name=myjob
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --container-image=nvcr.io/nvidia/pytorch:26.02-py3
#SBATCH --container-mount-home
set -euo pipefail
: "${TRAIN_SCRIPT:?Set the absolute training script path}"
[[ "$TRAIN_SCRIPT" = /* && -f "$TRAIN_SCRIPT" ]] || exit 2
# Placement evidence before the workload; abort on a mismatch with the packet.
nvidia-smi --query-gpu=name,uuid,memory.total,driver_version --format=csv
python -c 'import torch; assert torch.cuda.device_count() >= 4, torch.cuda.device_count()'
# The script must trap SIGTERM, save a checkpoint, and resume from the newest one.
exec python "$TRAIN_SCRIPT"
