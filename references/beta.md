# Beta (NVL72) cluster

Source: "Empire AI Beta NVL72 Cluster - Job Submission Guide" (PDF attached to the 2026-09-18
Cornell notice) and that notice. Beta is a different machine from Alpha: verify the login host,
the project account and the association listing before treating any value here as current.

## Shape

| Item | Value |
|---|---|
| Hardware | 72 nodes x 4 NVIDIA GB200 (288 GPUs), 189 GB HBM3e per GPU, NVLink |
| Architecture | Grace-Blackwell, ARM aarch64; x86 wheels and venvs do not transfer |
| Partition | one, `beta`; `--partition=beta` on every submission |
| Account | `--account=<project account>` required; the PI-to-account sheet names it |
| Software | no system Python or PyTorch on compute nodes; NGC containers via Pyxis/Enroot |
| Home | `/home/<user>` on shared VAST, 100 GB quota enforced |
| Project storage | `/projects/co/<project account>`, 8.333 SU per TB per month |
| Accounting | SU charging starts 2026-10-01; 1 SU = 1 GPU-hour at standard rate |
| Minimum job | 4 GPUs per NVL72 job (announced 2026-09-18); sub-4-GPU jobs will be terminated |

Single-GPU work belongs on the Alpha RTX 6000 Pro nodes. Empire AI may reserve four trays for
short single-GPU and interactive jobs; treat that as unavailable until the site announces it.

## QoS tiers

| QoS | Priority | Max wall | Max GPUs per job | Rate | Notes |
|---|---|---|---|---|---|
| priority | 1000 | 24 h | 72 | 2.0x | deadline work only |
| test | 800 | 6 h | 4 | 0.5x | one node; validate before every real run |
| interactive | 500 | 2 h | 4 | 1.0x | one session per user; `srun --pty bash`; dies with the SSH session, use tmux |
| standard | 500 | 48 h | 36 | 1.0x | default when `--qos` is omitted |
| long | 200 | 7 d | 36 | 0.5x | NoReserve: fills idle gaps only |
| burst | 0 | 7 d | 36 | free | system-assigned when the project budget is exhausted; preemptable |

SU = GPUs x hours x rate. Three limit layers reject a job at submission: QoS per user, project
budget (`GrpTRESMins`), institution cap. DenyOnLimit rejects instead of queueing. Running jobs
finish when the budget runs out; only new submissions move to burst.

Check: `sacctmgr show assoc where user=$USER format=Account%20,Partition%15,QOS%60`,
`sshare -u $USER -l`, `sacct -u $USER --format=JobID%10,JobName%20,QOS%12,AllocTRES%35,Elapsed,State -S today`.

## Wall time

Every tier has a wall limit and Slurm kills at the limit. The site recommends
`--requeue --signal=B:SIGTERM@900`: SIGTERM 15 min before the limit, the script saves a
checkpoint and exits, the job requeues and resumes. A requeued job goes back to PENDING and
competes on fairshare; it is not an instant restart. Each restarted run is billed separately.

For provenance-sensitive runs keep `--no-requeue` and resume through a new versioned
submission that cites the checkpoint; a silent requeue changes the allocation without a new
packet. Either way the training script must handle SIGTERM and resume from the latest
checkpoint. Keep the last few checkpoints only.

## Containers

- `--container-image=nvcr.io/nvidia/pytorch:26.02-py3` or newer. 24.12-py3 and earlier lack GB200 support.
- 26.02 prints `sm_100 is not compatible`; GPUs are detected and basic ops work, native Blackwell kernels come in a later NGC release. Check for NaN losses.
- `--container-name=<name>` caches the pulled image (first pull about 15 GB, several minutes). Do not combine with `bash -lc` torch commands.
- `--container-mounts=host:container` binds directories; `--container-mount-home` mounts `$HOME`. A home conda/pip can shadow the container's Python; omit it for `srun` torch checks.
- No `module` command; drop `module load` lines.

## Verification sequence

Run in this order on a new account or after a site change; each is one short job on `test`
or `interactive` and consumes allocation.

1. `srun --partition=beta --account=<acct> --qos=test --gres=gpu:1 --time=00:05:00 bash -c "nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv"` — expect `NVIDIA GB200`, driver 580.x, about 189 GB.
2. Same with `--gres=gpu:4 --container-image=nvcr.io/nvidia/pytorch:26.02-py3` and `python -c 'import torch; print(torch.cuda.device_count())'` — expect 4.
3. Add `--container-mount-home` and list `~` — confirms home is visible inside the container.
4. One `sbatch --wrap` per QoS tier the account is entitled to.
5. Requeue test: `--time=00:02:00 --requeue --signal=B:SIGTERM@60` with a trap that logs the signal.
6. Checkpoint save then resume across two jobs.

Record node name, GPU model, driver, container tag and job IDs; the announced 4-GPU minimum
means steps 1 and 3 may be rejected or terminated once enforcement lands.

## Errors specific to Beta

| Message | Cause | Fix |
|---|---|---|
| `invalid partition specified: alpha` | Beta has one partition | `--partition=beta` |
| `Invalid qos specification` | tier not in the association, or `burst` requested by hand | list tiers with `sacctmgr show assoc`; five user tiers only |
| `QOSMaxGRESPerJob` / `QOSMaxGRESPerUser` | over the tier GPU cap, or combined running jobs over the cap | fewer GPUs, wait, or a higher tier |
| `QOSMaxWallDurationPerJobLimit` | `--time` above the tier wall | shorter time or a longer tier, with requeue + checkpoint |
| `QOSMaxJobsPerUserLimit` | second interactive session | end the first one |
| `Requested node configuration is not available` | more than 4 GPUs on one node | `--nodes=N --gres=gpu:4` |
| `invalid account or account/partition combination` | wrong account, or several accounts and none named | `--account=<acct>` from the association list |
| PENDING `Reason=PartitionConfig` | default account not allowed on the partition | name the account explicitly |
| `pam_slurm_adopt: you have no active jobs on this node` | direct SSH to a compute node | `srun --qos=interactive --pty bash` |
| `ModuleNotFoundError: No module named 'torch'` | system Python used | run inside the container |
| `module: not found` | `module load` in the script | remove it |
| CUDA out of memory | workload, not scheduler | smaller batch, bf16, gradient checkpointing, more GPUs |
| `PREEMPTED` in sacct | burst job displaced by a paid tier | expected on burst; checkpoint |
| `CANCELLED ... DUE TO TIME LIMIT` | wall limit | requeue + checkpoint, or a longer tier |
