#!/bin/bash
# Single Empire poller. One bounded sacct query per interval over the owner's existing
# ControlMaster socket; exits when every listed job is terminal. Never opens a second
# connection loop and never retries a denied login.
#   POLL_HOST=empire POLL_JOBS=89298,89325 POLL_LOG=path POLL_INTERVAL=1800 assets/poll_jobs.sh
set -u
: "${POLL_HOST:?SSH host alias with an established master connection}"
: "${POLL_JOBS:?comma-separated Slurm job IDs}"
: "${POLL_LOG:?append-only log path}"
POLL_INTERVAL="${POLL_INTERVAL:-1800}"
POLL_TIMEOUT="${POLL_TIMEOUT:-60}"
[[ "$POLL_JOBS" =~ ^[0-9]+(,[0-9]+)*$ ]] || { echo "POLL_JOBS must be numeric job IDs" >&2; exit 2; }
[[ "$POLL_INTERVAL" =~ ^[0-9]+$ && "$POLL_INTERVAL" -ge 600 ]] || { echo "POLL_INTERVAL must be >= 600 seconds" >&2; exit 2; }
if [[ -z "${POLL_ALLOW_MULTIPLE:-}" ]]; then
  others=$(pgrep -f "poll_jobs.sh" | grep -v "^$$\$" | grep -v "^$PPID\$" || true)
  [[ -z "$others" ]] || { echo "another poller is running: $others" >&2; exit 3; }
fi
stamp() { date -u +%FT%TZ; }
while true; do
  # The master socket can hang without closing; bound the whole query, not only connect.
  out=$(timeout "$POLL_TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout=20 "$POLL_HOST" \
        "sacct -j $POLL_JOBS -X -o JobID,State,Elapsed,ExitCode -n -P" 2>/dev/null)
  rc=$?
  if [[ $rc -ne 0 || -z "$out" ]]; then
    echo "$(stamp) query failed rc=$rc (no retry inside the interval)" >> "$POLL_LOG"
  else
    echo "$(stamp) ${out//$'\n'/ | }" >> "$POLL_LOG"
    if ! grep -qE "RUNNING|PENDING|REQUEUED|COMPLETING|SUSPENDED|CONFIGURING" <<< "$out"; then
      echo "$(stamp) all terminal" >> "$POLL_LOG"
      exit 0
    fi
  fi
  sleep "$POLL_INTERVAL"
done
