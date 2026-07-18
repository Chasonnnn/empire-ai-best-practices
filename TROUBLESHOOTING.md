# Troubleshooting (every row was hit live — start here before re-deriving)

| Symptom | Cause | Fix |
|---|---|---|
| `Too many authentication failures` before any prompt | ssh-agent offered several keys, or a TTY-less shell looped silent empty prompts | `PubkeyAuthentication no` for this host (in [assets/ssh_config](assets/ssh_config)); log in only from a real terminal |
| Login "hangs" or `read_passphrase: can't open /dev/tty` | agent shells (and Claude Code's `!` prompt) have no TTY | a human logs in from a real terminal; agents ride the socket |
| `ssh empire` prompts again unexpectedly | ControlMaster socket expired (12h) or was killed | `ssh -O check empire` to confirm; ask the human for one fresh `ssh empire` |
| srun sits in `queued and waiting` indefinitely | GPU partition saturated | wrap in `timeout N` (revokes cleanly); `sbatch --test-only` shows projected start; `--qos=test` or `--qos=priority` to jump |
| Job dies at exactly 1h | partition DefaultTime is 1:00:00 | always pass `-t` |
| `lfs: command not found` inside a job | Lustre client tools absent on compute nodes | run `lfs quota` from the login node |
| CPU job never starts on `-p cpu` | that partition's single node was down | use `-p grace` (ARM aarch64 — needs ARM wheels) |
| `module load X/Y` not found | flat Bright-style module names, not EasyBuild trees | `module avail <term>` first; prefer own envs (SKILL.md §5) |
| Container runs on Alpha, fails on Beta | Beta is ARM64 + Enroot, Alpha is x86 + Apptainer | rebuild ARM64 images for Beta |
| Portal/FIDO links from memory don't resolve | two domains | ssh = `empire-ai.org` (hyphen); portal/support/Beta = `empireai.edu` |
| `uv venv --clear` fails: `Directory not empty (os error 39)` | NFS home: uv's internal remove trips on `.nfs` silly-rename files | `rm -rf <venv> || true` then plain `uv venv` (smoke_test.sh does this since 2026-07-18) |
| Job pends for hours with reason `AssocGrpGRESMinutes` — even on `--qos=test` | *account-wide* GPU-minutes cap (`GrpTRESMins gres/gpu=600000` on `cornell`) is near-exhausted; QOS does not bypass assoc limits; decay is slow (`PriorityDecayHalfLife=14d`, no reset), so the pool frees only as the account's running jobs finish | diagnose: `squeue -j <id> -O Reason`, `sshare -A cornell -o Account,User,RawUsage,TRESRunMins`, `scontrol show assoc_mgr account=cornell flags=assoc` (usage in parentheses). Jobs DO start as the pool drains — submit early to hold queue position, gate on job-log preflight rather than "starts within minutes", and never chain a same-night deadline on a job start |

Still stuck → the official docs table in SKILL.md §8, then a ticket at
https://empireai.freshdesk.com/support/home (NVIDIA office hours: Thursdays
2–3pm ET).
