# Troubleshooting (every row was hit live — start here before re-deriving)

| Symptom | Cause | Fix |
|---|---|---|
| `Too many authentication failures` before any prompt | ssh-agent offered several keys, or a TTY-less shell looped silent empty prompts | `PubkeyAuthentication no` for this host (in [assets/ssh_config](assets/ssh_config)); log in only from a real terminal |
| Login "hangs" or `read_passphrase: can't open /dev/tty` | agent shells (and Claude Code's `!` prompt) have no TTY | a human logs in from a real terminal; agents ride the socket |
| `ssh empire` prompts again unexpectedly | ControlMaster socket expired (48h default, or your configured `ControlPersist`) or was killed early by sleep/network change | `ssh -O check empire` to confirm; ask the human for one fresh `ssh empire` |
| srun sits in `queued and waiting` indefinitely | GPU partition saturated | wrap in `timeout N` (revokes cleanly); `sbatch --test-only` shows projected start; `--qos=test` or `--qos=priority` to jump |
| Job dies at exactly 1h | partition DefaultTime is 1:00:00 | always pass `-t` |
| `lfs: command not found` inside a job | Lustre client tools absent on compute nodes | run `lfs quota` from the login node |
| CPU job never starts on `-p cpu` | that partition's single node was down | use `-p grace` (ARM aarch64 — needs ARM wheels) |
| `module load X/Y` not found | flat Bright-style module names, not EasyBuild trees | `module avail <term>` first; prefer own envs (SKILL.md §5) |
| Container runs on Alpha, fails on Beta | Beta is ARM64 + Enroot, Alpha is x86 + Apptainer | rebuild ARM64 images for Beta |
| Portal/FIDO links from memory don't resolve | two domains | ssh = `empire-ai.org` (hyphen); portal/support/Beta = `empireai.edu` |
| `uv venv --clear` fails: `Directory not empty (os error 39)` | NFS home: uv's internal remove trips on `.nfs` silly-rename files | `rm -rf <venv> || true` then plain `uv venv` (smoke_test.sh does this since 2026-07-18) |
| `Invalid feature specification` from sbatch/scontrol when constraining GPU type | `--constraint` matches node FEATURES, not Gres type strings — `nvidia_h100_80gb_hbm3` is the Gres name; the feature is `nvidia_h100` (check `scontrol show node <n> \| grep AvailableFeatures`) | use `nvidia_h100` / `nvidia_h200`; OR syntax works with correct names (`--constraint="nvidia_h200\|nvidia_h100"`), and `scontrol update JobId=<id> Features=...` can widen a pending job |
| HF downloads run unauthenticated (`Warning: You are sending unauthenticated requests`) | no HF token exists anywhere on Empire by default (NFS cache, `~/.huggingface`, Lustre, profiles) — local-first workflows never installed one | copy your workstation token to `/mnt/home/<user>/.cache/huggingface/token` AND `$HF_HOME/token` on Lustre, `chmod 600` both; huggingface_hub re-reads the file per request | 
| `google/gemma-4-12B-it` downloads but fails to load: model type `gemma4_unified` not recognized | the 12B checkpoint uses the newer `gemma4_unified` architecture; the pinned QLoRA env's `transformers==5.5.0` predates it (31B `gemma4` and Qwen3.5-27B load fine) | bump transformers in a separate env before any `gemma12`-scope submission, or drop 12B from `warm_hf_cache.sh`; verified live 2026-07-18 |
| Job pends for hours with reason `AssocGrpGRESMinutes` — even on `--qos=test` | *account-wide* GPU-minutes cap (`GrpTRESMins gres/gpu=600000` on `cornell`) is near-exhausted; QOS does not bypass assoc limits; decay is slow (`PriorityDecayHalfLife=14d`, no reset), so the pool frees only as the account's running jobs finish | diagnose: `squeue -j <id> -O Reason`, `sshare -A cornell -o Account,User,RawUsage,TRESRunMins`, `scontrol show assoc_mgr account=cornell flags=assoc` (usage in parentheses). Jobs DO start as the pool drains — submit early to hold queue position, gate on job-log preflight rather than "starts within minutes", and never chain a same-night deadline on a job start |

Still stuck → the official docs table in SKILL.md §8, then a ticket at
https://empireai.freshdesk.com/support/home (NVIDIA office hours: Thursdays
2–3pm ET).
