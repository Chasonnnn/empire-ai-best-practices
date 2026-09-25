# Diagnose the current failure

Historical observations below are starting hypotheses. Confirm current account, scheduler state, and artifact identity before recovery. No row authorizes a submission, state edit, token transfer, or cleanup outside the task.

| Symptom | Check | Bounded correction |
|---|---|---|
| Too many authentication failures | Current host auth policy and offered keys; whether the login ran without a TTY | Use the approved host-specific configuration; the owner logs in from Terminal.app, not an agent prompt runner (2026-09-17) |
| Password/MFA prompt in automation | Master transport and BatchMode | Stop that operation; establish the approved interactive session |
| SSH master unavailable | Socket check and network/server state | Reconnect when authorized; ControlPersist is idle time, not a guarantee |
| Port 22 connection refused or timed out for hours | Recent auth failures and poller churn from this IP; other networks reach the host | Source-IP block (2026-09-17). Stop every SSH loop, do not retry, wait or use another network; run one poller afterwards |
| Poller tick never returns | Master socket state; query lacks a `timeout` wrapper | A dead socket hangs instead of failing (2026-09-18). Kill the tick, use `assets/poll_jobs.sh`, and let the owner re-login |
| Account or partition rejection | Full associations, selected project, current partitions | Resolve account, partition, QoS, and storage separately; institution partitions retired on Alpha on 2026-09-21 and `--account` is mandatory |
| Every job `NODE_FAIL` at once | Site maintenance or status dashboard | Maintenance kills running jobs (2026-09-21). Re-verify associations and partitions, then resume from checkpoints through fresh packets |
| Pending `InvalidQOS` after a site change | `sacctmgr show assoc user=$USER`: which account carries the QoS | QoS tiers moved to the project account on 2026-09-21. Update the target and prepare fresh packets; do not `scontrol update` submitted jobs |
| Job fails at start: account or QoS differs from the approved request | Whether the job was edited with `scontrol update` after submission | Expected fail-closed gate. Cancel, prepare a fresh packet, resubmit |
| Pending `QOSMaxWallDurationPerJobLimit` below the listed MaxWall | Time limits of running jobs under the same QoS | Alpha priority enforces 12 h in practice (2026-09-20). Use legs of at most 720 min or a longer QoS |
| Multiplexed ssh hangs from an agent shell, same call works in a terminal | Whether the command ran inside the agent sandbox | The sandbox blocks the mux fd hand-off (2026-09-18). Run it unsandboxed; do not ask for a re-login first |
| Login node busy long after a local timeout | `ps -u $USER` on the login node | Local `timeout` does not stop the remote command. Kill the remote pid |
| Beta-specific submission error (`invalid partition specified: alpha`, `QOSMax*`, `sm_100`, `module: not found`) | The [Beta error table](references/beta.md#errors-specific-to-beta) | Apply the listed fix; Beta has one partition and container-only nodes |
| Job under 4 GPUs terminated on Beta | Announced NVL72 minimum (2026-09-18) | Use 4 GPUs per node on Beta, or the Alpha RTX nodes for single-GPU work |
| QoS walltime reason | Current MaxWall and actual pending reason | A priority job at exactly MaxWall was held on 2026-08-09; request strictly below MaxWall and below the observed cap |
| Job ended at the wall limit (`TIMEOUT`, `CANCELLED ... DUE TO TIME LIMIT`) | Whether the script traps SIGTERM and writes a checkpoint | Add `--signal=B:SIGTERM@900` plus checkpoint-resume; requeue only when a silent restart is acceptable |
| Login-node CPU preflight dies with exit -9 | Model size and memory of the scan; no cgroup limit visible | Move large-model preflights to a short bounded GPU packet (2026-09-13); keep small manifest checks on the login node |
| Preflight passes, job fails at start on script hashes | Repository checkout on the cluster changed while the packet was pending | Never sync the cluster checkout while a packet cites it; rerun the preflight and resubmit with unchanged approved terms (2026-09-16) |
| Long queue delay | Current queue, priority, and association resource limits | Report current estimates without claiming a fixed wait or bypassing limits |
| CPU partition unavailable | Current node state and workload architecture | Do not automatically move x86 work to ARM because a CPU node was once down |
| Empty historical accounting | Query bounds, access, retention and active scheduler | Missing records/job-ID changes do not prove a reset; retain off-cluster manifests and outcomes |
| NFS environment removal fails | Active users and .nfs references | Use a new task-owned environment path; do not rm -rf a shared environment or ignore removal errors |
| Invalid GPU constraint | Node AvailableFeatures versus GRES names | Use the currently advertised constraint/resource syntax |
| Requested partition or GPU type changed after submission | Submit-time stderr, inherited `SBATCH_*` values, active job-submit plugin and scheduled readback | Follow the [placement gates](references/placement.md); client flags cannot override server-side policy, and unrouted fields are not a bypass route |
| Placement mismatch includes a following key, such as `Partition=alpha AllocNode:Sid=...` | Parser handling of colon/slash keys and empty values | Reproduce using full scheduler output; preserve the old record and capture corrected evidence before authorized cancellation or retry |
| Pending job has an untyped GPU count | Declared physical expectation versus allocation evidence | Leave physical verification unresolved until the compute-node check; do not infer a GPU model from an untyped count |
| Unauthenticated model download | Current credential method and HF_HOME | Use approved auth if needed; do not infer token absence everywhere or copy a workstation token to multiple paths by default |
| Unknown model architecture | Pinned package/model revisions and supported architecture | Prepare a separate compatible environment, document the exception, and test it |
| Job fails immediately on a manifest | Submitted code/schema/input hashes | Fix and revalidate a new versioned input set; do not mutate pending snapshots |
| Bootstrap cannot resolve a Python version | Approved uv/runtime versions and actual support | Plan a validated tool upgrade or compatibility exception; do not run a floating installer every session |
| Home cache grows unexpectedly | HF_HOME/local-dir and actual cache ownership | Stage to approved storage; clean only identified task-owned obsolete data |
| Watcher sees a process forever | Job ID, process identity and expected artifacts | Pattern matches can include wrappers; adjacent quoted strings concatenate and do not generally prevent self-matches |
| Interrupted transfer | Command options, destination state and partial artifacts | Reconcile before retrying; do not call every rsync invocation idempotent |

Escalate unresolved host policy questions to [Empire support](https://empireai.freshdesk.com/support/home) with sanitized errors and job identifiers.
