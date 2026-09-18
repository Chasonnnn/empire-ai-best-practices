# Empire AI best practices

Agent skill for Empire AI access, environment staging, Slurm jobs, and diagnosis on the Alpha (Hopper/RTX, venvs) and Beta (GB200 NVL72, containers) clusters. The root routes to setup, job operation, Beta specifics, troubleshooting, and dated cluster context.

Assets: `job_template.sbatch` (Alpha venv job), `beta_job_template.sbatch` (Beta container job with SIGTERM checkpointing), `poll_jobs.sh` (single bounded poller), `ssh_config`, and the legacy BERT smoke submitter.

Account, partition, QoS, storage root, runtime, and workload revisions are explicit inputs. The legacy BERT/SST-2 helper requests one untyped GPU without placement checks, so site policy can override its partition and GPU identity. Use its workload through a guarded project executor; scheduler completion and accuracy alone do not establish the requested hardware. It performs no dependency installation or prior-run deletion.

Install the repository as `empire-ai-best-practices` in the agent's skill directory, preferably through a symlink to one maintained checkout. See [SKILL.md](SKILL.md) for task boundaries and [references/jobs.md](references/jobs.md) for required smoke inputs.

Run local regression checks with the approved Python runtime:

```sh
python -m unittest discover -s tests -v
```

Local checks use fake modules and a fake scheduler. They do not validate live Empire configuration, package compatibility, GPU execution, model/data access, or accuracy.
