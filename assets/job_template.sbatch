#!/bin/bash
# Empire AI Alpha batch template (validated). Replace INSTITUTION (= account = partition).
#SBATCH -A INSTITUTION
#SBATCH -p INSTITUTION
#SBATCH --gres=gpu:1            # --constraint=nvidia_h200 for 141GB nodes; --qos=test for quick debug
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH -t 04:00:00             # DefaultTime is only 1h — always set -t
#SBATCH -J myjob
#SBATCH -o /mnt/home/%u/logs/%x-%j.out

export HF_HOME=/mnt/lustre/INSTITUTION/$USER/hf   # internet works in jobs; pre-stage big weights anyway
source ~/venvs/myproject/bin/activate             # own latest-stable env (SKILL.md §5)
python train.py
