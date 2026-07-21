# Empire AI Best Practices

A field-tested runbook and [Claude Code skill](https://code.claude.com/docs/en/skills)
for the [Empire AI](https://www.empireai.edu/) **Alpha** cluster. Every fact in it was
validated by running it live on the cluster (2026-07-17) — including the parts that
failed first: the SSH/TOTP auth dead-ends, the 1-hour default time limit, the down
partition, the module quirks. Those pivots are captured so your agent doesn't have to
rediscover them.

**What's covered**

- The only connection pattern that works for AI agents (human logs in once with TOTP,
  agents ride a 48h SSH ControlMaster socket — no keys, no TTY; window is
  client-side and configurable)
- Cluster map: institution GPU partitions (H100 + H200, confirmed accessible), the
  `coldfront_test` H200 side door, ARM `grace` nodes, the QOS priority ladder
- Storage layout (home vs Lustre, no-backup warning), HF cache placement
- Dependency policy: latest-stable in your own `uv` envs; modules are bootstrap-only
- Validated Slurm job patterns: bounded probes, `--test-only`, sacct polling
- A self-configuring end-to-end smoke test (BERT × SST-2, ~1 SU)
- A symptom→cause→fix table of every failure hit during validation
- Links to all official Empire AI documentation

## Install (Claude Code)

```bash
git clone https://github.com/Chasonnnn/empire-ai-best-practices.git \
  ~/.claude/skills/empire-ai-best-practices
```

Then:

1. Open [SKILL.md](SKILL.md) §0 and note your username + institution (that's the whole
   personalization).
2. New to the cluster, or a machine that has never connected? Follow
   [SETUP.md](SETUP.md) — account, FIDO/TOTP enrollment, SSH config.
3. Optionally prove the whole chain works: `bash assets/smoke_test.sh` (run on the
   cluster; it configures itself). It spends a few SUs (~10 GPU-min), so agents
   should offer it and let the user decide rather than running it automatically.

Claude Code picks the skill up automatically whenever cluster work comes up. Other
agents (Codex, etc.): the files are plain markdown — point your agent at `SKILL.md`.

## Contents

| File | Purpose |
|---|---|
| [SKILL.md](SKILL.md) | The runbook: connection protocol, cluster map, storage, env policy, job patterns |
| [SETUP.md](SETUP.md) | One-time setup: account, FIDO portal, TOTP binding, SSH config |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Symptom→cause→fix table from live validation |
| [assets/ssh_config](assets/ssh_config) | ControlMaster SSH config block (the auth pattern that works) |
| [assets/job_template.sbatch](assets/job_template.sbatch) | Validated batch job starting point |
| [assets/smoke_test.sh](assets/smoke_test.sh) | Self-configuring end-to-end test (env → sbatch → BERT train) |

## Keeping it current

The cluster evolves (Beta/GB200 is onboarding now). When you hit something new, fix it
here and open a PR — the value of this repo is that the *next* person's agent doesn't
re-derive it. Facts not yet validated live are explicitly marked **UNVERIFIED** in
SKILL.md.

*Community-maintained; not an official Empire AI resource. Official docs are linked in
SKILL.md §8. If your work uses Empire AI, cite it (see the citation link there).*
