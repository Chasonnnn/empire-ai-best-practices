#!/bin/bash
# Single Empire poller. One bounded sacct query per interval (default hourly) over the owner's existing
# ControlMaster socket; exits when every listed job is terminal. Never opens a second
# connection loop and never retries a denied login.
#   POLL_HOST=empire POLL_JOBS=89298,89325 POLL_LOG=path POLL_INTERVAL=3600 assets/poll_jobs.sh
set -u
: "${POLL_HOST:?SSH host alias with an established master connection}"
: "${POLL_JOBS:?comma-separated Slurm job IDs}"
: "${POLL_LOG:?append-only log path}"
POLL_INTERVAL="${POLL_INTERVAL:-3600}"
POLL_TIMEOUT="${POLL_TIMEOUT:-60}"
[[ "$POLL_JOBS" =~ ^[0-9]+(,[0-9]+)*$ ]] || { echo "POLL_JOBS must be numeric job IDs" >&2; exit 2; }
# Owner rule 2026-09-20: at most one Empire contact per hour while jobs run.
[[ "$POLL_INTERVAL" =~ ^[0-9]+$ && "$POLL_INTERVAL" -ge 3600 ]] || { echo "POLL_INTERVAL must be >= 3600 seconds" >&2; exit 2; }
if [[ -z "${POLL_ALLOW_MULTIPLE:-}" ]]; then
  # Exclude this process, its parent, and its children: `caffeinate -s script` execs the
  # script and spawns a helper child whose cmdline still names the script (macOS, 2026-09-18).
  # No command substitution: a $( ) subshell would carry this script's own cmdline.
  scratch="${TMPDIR:-/tmp}/poll_jobs.$$.pids"
  pgrep -f "poll_jobs.sh" > "$scratch" 2>/dev/null || true
  pgrep -P "$$" > "$scratch.kids" 2>/dev/null || true
  others=""
  while read -r pid; do
    [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
    grep -qx "$pid" "$scratch.kids" && continue
    others="$others $pid"
  done < "$scratch"
  rm -f "$scratch" "$scratch.kids"
  [[ -z "${others// /}" ]] || { echo "another poller is running:$others" >&2; exit 3; }
fi
stamp() { date -u +%FT%TZ; }
# Final only when every requested job has a row in a terminal state. A missing row is unresolved;
# PREEMPTED can requeue, so it keeps the poller running.
all_terminal() {
  local id state
  for id in ${POLL_JOBS//,/ }; do
    state=$(awk -F'|' -v j="$id" '$1==j {split($2, s, " "); sub(/\+$/, "", s[1]); print s[1]; exit}' <<< "$1")
    case "$state" in
      COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|BOOT_FAIL|DEADLINE) ;;
      *) return 1 ;;
    esac
  done
}
while true; do
  # The master socket can hang without closing; bound the whole query, not only connect.
  out=$(timeout "$POLL_TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout=20 "$POLL_HOST" \
        "sacct -j $POLL_JOBS -X -o JobID,State,Elapsed,ExitCode -n -P" 2>/dev/null)
  rc=$?
  if [[ $rc -ne 0 || -z "$out" ]]; then
    echo "$(stamp) query failed rc=$rc (no retry inside the interval)" >> "$POLL_LOG"
  else
    echo "$(stamp) ${out//$'\n'/ | }" >> "$POLL_LOG"
    if all_terminal "$out"; then
      echo "$(stamp) all terminal" >> "$POLL_LOG"
      exit 0
    fi
  fi
  sleep "$POLL_INTERVAL"
done
