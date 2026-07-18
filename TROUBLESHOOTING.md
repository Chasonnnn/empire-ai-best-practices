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

Still stuck → the official docs table in SKILL.md §8, then a ticket at
https://empireai.freshdesk.com/support/home (NVIDIA office hours: Thursdays
2–3pm ET).
