---
name: empire-ai-best-practices
description: Use when working with the Empire AI cluster (alpha.empire-ai.org, Alpha/Grace/Beta) — running experiments, training, or batch inference there; submitting, monitoring, or debugging Slurm jobs; staging data or models; SSH/ControlMaster connection issues; or first-time account setup.
---

# Empire AI Cluster Runbook

New York State's academic AI cluster. Every fact below was validated by running it
live on Alpha on 2026-07-17 unless marked **UNVERIFIED**. Two domains, easy to mix
up: SSH host is `alpha.empire-ai.org` (hyphen); the FIDO credential portal,
support, and Beta are `empireai.edu`.

## 0. Personalize (edit when adopting this skill)

```
USER        = <your-empire-ai-username>   # on a configured machine: the User line of the "Host empire" block in ~/.ssh/config
INSTITUTION = <your-institution>          # = your Slurm account AND GPU partition (cornell/columbia/nyu/rpi/suny/cuny/rochester/rit/mountsinai/scc)
```
On the cluster, derive it: `sacctmgr -nP show assoc user=$USER format=Account`.
New user or unconfigured machine → follow [SETUP.md](SETUP.md) first.

## 1. Connection protocol (the ONLY auth path that works for agents)

Auth = password + TOTP code on **every new connection**; no SSH public keys; agent
shells have no TTY. So:

1. A **human** logs in once from a real terminal: `ssh empire` (config from
   [assets/ssh_config](assets/ssh_config)). They may exit immediately — the
   ControlMaster socket persists **48h** (default; `ControlPersist` in the config).
2. Agent verifies `ssh -O check empire` → `Master running`, then runs everything
   via `ssh empire '<cmd>'` / `scp` / `rsync -e ssh`, prompt-free.
3. Use `-o BatchMode=yes` in scripts and pollers so a dead socket fails fast.
4. Socket lapsed → ask the human for one fresh `ssh empire`; nothing else works.
5. `ControlPersist` is **client-side only** — no server policy caps it, so longer
   windows are fine. The real bound is network continuity: laptop sleep or a
   network change drops the TCP connection and kills the master regardless of
   the setting. Changing the value takes effect on the **next** fresh login, not
   the currently running master.

## 2. Cluster map (Alpha)

| Partition | Nodes | Hardware | Validated result |
|---|---|---|---|
| `INSTITUTION` (e.g. `cornell`) | alphagpu01–24 (x86, 2 TB RAM, 8 GPU/node) | H100 80GB on gpu01–18, **H200 141GB on gpu19–24** | busy (~20 pending) yet a 1-GPU 5-min job ran within ~10 min |
| `coldfront_test` | alphagpu19–24 | H200-only side door, AllowAccounts=ALL, 6h cap | `--test-only` accepted with QOS `test` |
| `grace` | betagg01–60 + alphagh01 | **ARM aarch64** Grace, CPU-only | **instant allocation**, mostly idle |
| `cpu` | alphacpu01 | single x86 CPU node | was down — use `grace` |

- **H200 access confirmed** (verified on a cornell account): `--gres=gpu:nvidia_h200:1`
  or `--gres=gpu:1 --constraint=nvidia_h200`. Waits are occupancy, not permissions.
  GRES names: `gpu:nvidia_h200`, `gpu:nvidia_h100_80gb_hbm3`.
- **QOS ladder** (standard institution assoc): `cornell`-style default (prio 0, 7d,
  ~30 jobs) · `standard` (500, 2d, ≤32 GPU) · `test` (800, 2h, ≤8 GPU — debug lane)
  · `priority` (1000, 1d, ≤64 GPU, **2× SU**; cut a projected start 15→3 min).
- Partition: DefaultTime **1:00:00** (always set `-t`), MaxTime 7d, `PreemptMode=REQUEUE`.
  ~1 SU per Alpha GPU-hr (~$0.50); ~20k SU/project/yr; balance CLI **UNVERIFIED**
  (portal = ColdFront; ask support).
- **Beta** (GB200 NVL72): ARM + Enroot, early-adopter now; Alpha x86 images do
  not port — ARM64 rebuild. Institution Beta access **UNVERIFIED**.

## 3. Storage

| Path | Role | Notes |
|---|---|---|
| `/mnt/home/USER` | code, envs, sbatch, logs | ~100 GB cap (docs); NFS |
| `/mnt/lustre/INSTITUTION/USER` | datasets, HF cache, checkpoints | pre-created; **NO backups** — replicate precious results off-cluster (Globus collection "Empire AI Alpha", or rsync over the socket) |
| `/dev/shm`, `/tmp` | node-local scratch | shm counts against `--mem`; ~880 GB NVMe root on GPU nodes |

In jobs: `export HF_HOME=/mnt/lustre/INSTITUTION/USER/hf`.

## 4. Software & dependency policy: LATEST STABLE, own envs

- Modules are **bootstrap only** — they lag (`Python/3.10.15`, `CUDA/13.1`,
  `apptainer/1.1.9`; flat Bright-style names, no conda module).
- Build your own env with `uv` (install: `curl -LsSf https://astral.sh/uv/install.sh | sh`):
  current Python + latest stable torch/transformers. Validated result: Python
  3.13.12 + torch 2.13.0+cu130 built and ran first try. Check for updates at
  project start rather than pinning to what the cluster ships.
- **Internet works on login AND compute nodes** (verified from inside a GPU job) —
  `pip install` / `hf download` work anywhere; still pre-stage multi-GB weights to
  Lustre so queue time isn't spent downloading.
- Compute-node system `python3` differs from the login node's — never rely on it.
  `grace` nodes are aarch64 → ARM wheels only. Apptainer for containerized runs.

## 5. Job patterns (validated)

- Batch: start from [assets/job_template.sbatch](assets/job_template.sbatch).
  Check schedulability without queueing: `sbatch --test-only ...` prints projected start.
- Bounded interactive probes — `timeout` on a pending srun revokes it cleanly:
  `ssh empire 'timeout 100 srun -A INSTITUTION -p INSTITUTION --gres=gpu:1 -t 00:05:00 bash -c "hostname; nvidia-smi -L"'`
- Monitor: `squeue -u $USER` · `sacct -j <id> -X -o State,Elapsed` · `scancel <id>`.
  Agent-side: poll `sacct` over the socket every ≥60s and act on ALL terminal
  states (COMPLETED/FAILED/CANCELLED/TIMEOUT/OUT_OF_MEMORY/NODE_FAIL/PREEMPTED).
- Fresh setup? The end-to-end smoke test is **optional and costs SUs** — offer it
  and let the user decide, don't auto-run it: [assets/smoke_test.sh](assets/smoke_test.sh)
  (self-configuring BERT/SST-2; expected `RESULT accuracy=0.92xx` — measured run:
  0.9266, 27s train on 1× H100 at ~2,480 samples/s, well under 1 SU).

## 6. Workload sizing (LLM/encoder reference points)

- Encoder-scale (≤1B): 1× H100; seed sweeps as job arrays (~1 SU/hr each).
- 12B–31B LoRA/QLoRA: 1× H200 (`--constraint=nvidia_h200`). Full fine-tune: one
  node `-N 1 --gres=gpu:8`, FSDP/DeepSpeed over NDR InfiniBand. The
  `gemma-trainer` skill's TRL/Unsloth recipes apply here (CUDA-only).
- Batch inference ≤31B: 1× H200 bf16, or vLLM in Apptainer.
- Stage weights from the login node:
  `hf download <repo> --local-dir /mnt/lustre/INSTITUTION/USER/models/<name>`

## 7. When something breaks

[TROUBLESHOOTING.md](TROUBLESHOOTING.md) — a symptom→cause→fix table of every
failure hit during validation. Check it before re-deriving.

## 8. Official documentation

| Topic | Link |
|---|---|
| Support portal / tickets / wiki | https://empireai.freshdesk.com/support/home |
| Getting started | https://empireai.freshdesk.com/support/solutions/articles/157000374441 |
| CCR Buffalo Empire AI guide | https://docs.ccr.buffalo.edu/en/latest/howto/empireai/ |
| Connecting to Alpha | https://empireai.freshdesk.com/support/solutions/articles/157000010767 |
| Submitting jobs | https://empireai.freshdesk.com/support/solutions/articles/157000010768 |
| Slurm partitions/queues | https://empireai.freshdesk.com/support/solutions/articles/157000168778 |
| Alpha/Beta hardware | https://empireai.freshdesk.com/support/solutions/articles/157000363466 |
| Service units & allocations | https://empireai.freshdesk.com/support/solutions/articles/157000363467 |
| Alpha storage | https://empireai.freshdesk.com/support/solutions/articles/157000175046 |
| Sharing data with other users | https://empireai.freshdesk.com/support/solutions/articles/157000010953 |
| Citation guidelines (**cite Empire AI in every paper that used it**) | https://empireai.freshdesk.com/support/solutions/articles/157000359451 |
| Reporting project highlights | https://empireai.freshdesk.com/support/solutions/articles/157000363495 |

## 9. Etiquette

- Login nodes (alpha1/alpha2): probes, downloads, edits only — no heavy compute.
- NVIDIA office hours: Thursdays 2–3pm ET (link in the login banner).
- Sharing files: NFS home = NFSv4 ACLs by numeric UID (`nfs4_setfacl`); Lustre = POSIX ACLs.
