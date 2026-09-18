# Environments, submission, and monitoring

## Prepare

Keep code and small environment metadata in the appropriate home/project area and datasets, weights, caches, and outputs in the approved storage allocation. Verify the actual storage root and quotas; do not derive it from a Slurm account. Retain important artifacts off-cluster according to current backup policy. Set HF_HOME for both staging commands and jobs; login-shell downloads otherwise may fill the home cache.

Storage after the 2026-09-18 notice: Beta home directories have an enforced 100 GB quota; Beta project storage is `/projects/co/<project account>` at 8.333 SU per TB per month; Alpha keeps `/mnt/lustre/<institution>/<user>`. Venvs with torch run 10 to 20 GB each, so several of them in a home directory exceed a 100 GB quota. Keep venvs, HF caches, checkpoints and datasets on project storage, review it monthly and remove what no run cites.

Use the project's lockfiles and approved runtime. Record any architecture/CUDA compatibility exception. Prepare dependencies before consuming a GPU allocation; do not assume login-node system Python matches compute nodes. Keep the selected environment unchanged while submitted jobs reference it. Stage model/data revisions and record the actual environment, input hashes, and source revision.

Validate manifests, schema compatibility, file availability, and other lightweight checks before submission using the same code path as job-start validation. “CPU-only” does not automatically make a large scan suitable for a login node. For provenance-sensitive work, isolate submitted inputs and verify their hashes at job start. Changes require a new versioned submission; do not silently alter pending experiments. Retain failed attempts as described in [placement provenance](placement.md#preserve-failed-attempts).

## General job template

The bundled templates do not implement the [placement gates](placement.md). Use a project executor that implements them, or add them to a new packet before submission.

`assets/job_template.sbatch` uses the selected environment interpreter directly and fails if it is absent. From the intended project working directory, export absolute PROJECT_PYTHON and TRAIN_SCRIPT paths and an existing writable HF_HOME. Submit with explicit `--account ACCOUNT --partition PARTITION` and optional `--qos QOS`. The template writes `slurm-JOBID.out` in the submission directory, avoiding a hidden dependency on ~/logs. Override resources to match the workload and current scheduler policy.

Always specify walltime, strictly below the QoS MaxWall. Query current account/partition/QoS limits and architecture when needed. `sbatch --test-only` is a scheduling estimate, not a reservation or guarantee of start time. A local `timeout` does not prove remote work was cancelled.

Every tier kills at the wall limit. Add `--signal=B:SIGTERM@900` and have the training script save a checkpoint on SIGTERM and resume from the newest one. `--requeue` is opt-in: it restarts the job as a new billed allocation on the same job ID without a new packet, so provenance-sensitive executors keep `--no-requeue` and resume through a new versioned submission that cites the checkpoint. A requeued job re-enters PENDING and competes on fairshare.

`assets/beta_job_template.sbatch` is the container-based Beta counterpart: `--partition=beta`, 4 GPUs per node, `--container-image` and `--container-mount-home`, the SIGTERM signal, and a device-count check before the workload. See [beta.md](beta.md).

## Optional BERT/SST-2 smoke job

`assets/smoke_test.sh` is a legacy submitter, not a complete validation command. It hardcodes one untyped GPU (`--gres=gpu:1`) and does not hold, read back placement, or verify the physical GPU. Under the [2026-09-11 Alpha routing observation](cluster-context.md), governed single-GPU requests land on RTX even if `SLURM_PARTITION` names Cornell. Scheduler exit and `result.json` cannot detect that substitution. Do not use it directly for a hardware-bound approval; use its workload through a guarded project executor. It performs no installation, deletes no prior environment, and creates a unique run directory below LUSTRE_ROOT/smoke-runs. Each run copies its script and lockfile, records actual package versions and input hashes, and keeps scheduler logs/results separate.

Export these explicit inputs before calling it:

- SLURM_ACCOUNT and SLURM_PARTITION; optional SLURM_QOS.
- LUSTRE_ROOT: existing approved writable absolute storage root.
- SMOKE_PYTHON: absolute executable from a prepared environment containing torch, transformers, datasets, and accelerate.
- SMOKE_LOCKFILE: the lock used to prepare that environment. The manifest records the actual installed packages; copying a lock does not establish that the environment matches it.
- MODEL_REVISION and DATASET_REVISION: full commit hashes for bert-base-uncased and nyu-mll/glue, respectively.
- SMOKE_MIN_ACCURACY: a finite threshold between zero and one selected for the pinned workload. The historical 0.9266 result is not a universal acceptance threshold.

Do not update the referenced environment while the job is pending/running. The workload still requires access to the pinned model/data, suitable GPU support, and package API compatibility. A failure leaves the run directory for diagnosis. An uncertain sbatch response requires scheduler reconciliation before any retry.

## Completion

Use the recorded job ID. Check live state with squeue and allocation records with `sacct -j JOBID -X --format=JobIDRaw,State,ExitCode,Elapsed -P`. Record query errors and accounting delay separately from job outcomes.

Polling rules (owner, 2026-09-17): one poller per workstation, one `sacct` query per 30 minutes over the owner's existing ControlMaster socket, exit when every job is terminal. `assets/poll_jobs.sh` implements this: it refuses to start beside another poller, rejects intervals under 10 minutes, wraps each query in `timeout` so a dead socket cannot hang the tick, and logs a failed query without retrying inside the interval. Never poll with a second SSH loop, a Monitor tool tail, or `squeue` in a tight loop; connection churn from one IP led to a multi-hour sshd block. If the socket dies, the poller logs failures until the owner re-logs in; do not attempt the login from automation.

COMPLETED plus ExitCode 0:0 is scheduler success. FAILED, CANCELLED, TIMEOUT, OUT_OF_MEMORY, NODE_FAIL, BOOT_FAIL, and DEADLINE are failure outcomes. Normalize state annotations such as a trailing `+` or cancellation details. PREEMPTED can transition to requeue; inspect the active job and newest allocation state before treating it as final. REQUEUED, pending, and running states are not final. Unknown states or missing records are unresolved, not success; consult the installed scheduler's current state definitions.

For the BERT smoke workload, success requires matching physical placement plus scheduler success and a valid `output/result.json` with status passed and finite accuracy meeting the declared threshold. A CUDA-only readiness check has its own result contract; it does not validate training, model inference or benchmark comparability. Inspect stderr/logs for the correct run. If waiting expires, report validation pending and retain the job ID; do not automatically cancel or resubmit. Cleanup only completed task-owned runs when authorized.

[Slurm states](https://slurm.schedmd.com/job_state_codes.html) · [sbatch](https://slurm.schedmd.com/sbatch.html)
