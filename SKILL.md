---
name: empire-ai-best-practices
description: Set up Empire AI access, stage environments and data, and submit, monitor, or debug its Slurm jobs on the Alpha and Beta clusters.
---

# Empire AI

Use the requested institution, project, workload, and authorization. SSH uses `alpha.empire-ai.org`; credential/support services use the `empireai.edu` domain. Current account, partition, QoS, storage, and architecture settings are inputs, not interchangeable institution names.

## Two clusters

| | Alpha | Beta |
|---|---|---|
| GPUs | H100 80 GB, H200 141 GB, RTX PRO 6000 Blackwell (x86); Grace nodes are ARM | GB200 NVL72, 4 per node, 189 GB (ARM aarch64) |
| Partitions | institution partitions until the 2026-09-21 maintenance, then `alpha` and `grace`; `--account` required | `beta` only; `--account` required |
| Software | project venvs on Lustre/home | NGC containers via Pyxis/Enroot only; no system Python |
| Minimum job | site routing sends 1-GPU jobs to RTX; multi-GPU untyped requests exclude RTX | 4 GPUs; smaller jobs will be terminated |
| Storage | `/mnt/lustre/<inst>/<user>` | `/projects/co/<account>`; home 100 GB quota |
| Accounting | QoS with priority/standard tiers | SU tiers, charged from 2026-10-01 |

Details: [references/beta.md](references/beta.md) for Beta; [references/cluster-context.md](references/cluster-context.md) for Alpha routing evidence; [references/notice_2026-09-18.md](references/notice_2026-09-18.md) for the announcement text and [references/beta_nvl72_job_submission_guide.pdf](references/beta_nvl72_job_submission_guide.pdf) for the site guide itself.

## Task routes

- First access or SSH trouble: [SETUP.md](SETUP.md) and [assets/ssh_config](assets/ssh_config).
- Environment, storage, and submission: [references/jobs.md](references/jobs.md).
- Beta submission, QoS tiers, containers, checkpointing: [references/beta.md](references/beta.md) and [assets/beta_job_template.sbatch](assets/beta_job_template.sbatch).
- Scheduler rewrites, held submission, and physical GPU verification: [references/placement.md](references/placement.md).
- Monitoring: [assets/poll_jobs.sh](assets/poll_jobs.sh) and the completion section of [references/jobs.md](references/jobs.md); failed runs: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

Resolve `SLURM_ACCOUNT`, `SLURM_PARTITION`, `SLURM_QOS`, and the storage root separately from approved project context and a current `sacctmgr show assoc` listing. Do not select the first association when multiple projects are possible. A failed lookup leaves configuration unresolved. After a site migration (partition rename, new cluster) re-run the association and partition checks before touching any tracked target config.

## Connection discipline

The site's sshd blocks the source IP after repeated authentication failures or connection churn; a block takes the whole workstation off the cluster for hours (observed 2026-09-17).

- Interactive login (password + Duo) needs a real TTY. The owner runs `ssh empire` in Terminal.app; an agent prompt runner produces `Too many authentication failures`. Never request passwords, tokens, or MFA codes in chat.
- Automation uses the established ControlMaster socket with `BatchMode=yes`. Check with `ssh -O check empire` first. If the socket is dead or the login is denied, stop and hand off; never retry the same login.
- One poller per workstation, one bounded `sacct` query per 30 minutes, exit on terminal state. Check `pgrep -fl poll_` before starting one. Wrap the query in `timeout`: a dead socket hangs rather than fails (observed 2026-09-18). No Monitor tool tailing over SSH.
- Never start an interactive login attempt while a poller is running.

## Compute discipline

- GPU allocations are for GPU steps only. Manifest checks, hashing, packaging and scoring run on the login node, on the workstation, or on AWS. Large-model CPU scans can be SIGKILLed on the login node without a visible cgroup limit (exit -9, observed 2026-09-13); move those to a short bounded GPU packet.
- Login nodes are for lightweight checks, staging, and edits. Validate input contracts before queueing with the same inexpensive preflight used at job start.
- Keep the environment and every path a pending packet references unchanged. Do not sync the repository checkout on the cluster while a pending packet cites it (a resync between preflight and start failed a job on 2026-09-16). Use snapshots when provenance matters.
- Request wall time strictly below the QoS MaxWall. Every tier kills at the limit; the training script must trap SIGTERM (`--signal=B:SIGTERM@900`), save a checkpoint and resume. `--requeue` is opt-in and creates a new billed run; provenance-sensitive runs keep `--no-requeue` and resume through a new versioned submission.
- Preserve project runtime declarations and locks. New environments start from the approved baseline with explicit cluster compatibility exceptions (x86 Alpha venvs, aarch64 Beta containers). Do not upgrade tools or dependencies merely because a new task starts.
- Home directories carry a 100 GB quota on Beta and are finite on Alpha. Venvs, HF caches, checkpoints and datasets live on project storage; set `HF_HOME` for staging commands and jobs alike.

## Approval and validation

The optional smoke workload consumes allocation. Approval is bound to the hardware, duration, purpose and other limits it names, including GPU count, account, storage and permitted attempts. An unchanged approved request needs no repeated confirmation; changing any approved term requires a new owner go. A scheduler rewrite is not permission to substitute hardware, and another agent cannot supply owner approval.

Use the [placement gates](references/placement.md) before releasing a job and before starting its workload. `assets/smoke_test.sh` is a legacy one-GPU BERT/SST-2 submitter without these gates; site policy reroutes single-GPU jobs to RTX despite its partition argument. Finish validation by checking actual placement, scheduler outcome and workload results. A timeout, missing accounting, or successful submission is not a completed test.

Do not repeat a submission, cancel jobs, modify pending inputs, or clean shared environments merely because a local command failed. Reconcile job IDs and actual state first and stay within the task's retry/cleanup authority. Report prepared, submitted, running, completed, workload-validated, and unresolved states distinctly.
