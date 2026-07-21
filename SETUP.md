# First-time setup (new Empire AI users)

Done when `ssh -O check empire` prints `Master running (pid=...)`. Until then, work
through these steps in order.

## 1. Account & credentials

1. Request an account through your institution's Empire AI representative.
2. Set your password at the FIDO portal `https://fido.empireai.edu`. Enrollment
   uses an out-of-band PIN (delivered in person or by text — never email) plus a
   confirmation mail from `FIDO@empireai.edu`.
3. Your **first SSH login displays a QR code** — scan it with a TOTP authenticator
   app (Duo / Google / Microsoft Authenticator; it acts as a 6-digit code
   generator, not push approval).

## 2. SSH configuration

1. Copy [assets/ssh_config](assets/ssh_config) into `~/.ssh/config`, replacing
   `USER` with your Empire AI username.
2. Ask the user how long one login should stay valid (`ControlPersist`).
   **Default: 48h.** It is client-side only (no server policy caps it); the real
   bound is network continuity — sleep or a network change kills the socket
   early regardless of the setting. Pick shorter if they prefer re-auth more
   often on a shared machine.
3. `mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets`
4. The `PubkeyAuthentication no` line is load-bearing: the server has no pubkey
   auth, and an ssh-agent offering several keys exhausts the server's auth
   attempts before the password prompt appears (see TROUBLESHOOTING.md).

## 3. First login — human, real terminal

The login is interactive (password + TOTP) and agent shells have no TTY, so a
**human** runs it in a real terminal window (for Claude Code users: a normal
Terminal/iTerm window — the `!` prompt has no TTY either):

```
ssh empire
```

Password → 6-digit code → you're in. You may `exit` immediately; the
ControlMaster socket persists 48h (or your configured window) and every
subsequent agent command rides it.

## 4. Verify

- `ssh -O check empire` → `Master running (pid=...)`
- `ssh empire 'sacctmgr -nP show assoc user=$USER format=Account'` → your
  INSTITUTION value for SKILL.md §0.
- **Optional** full validation — it spends SUs, so ask the user whether they
  want to run it rather than running it automatically:
  [assets/smoke_test.sh](assets/smoke_test.sh) (self-configuring BERT/SST-2
  training job, ~10 GPU-min, ~$0.10 in SUs).
