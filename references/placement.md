# Requested resources and actual placement

## Submission gate

A job ID proves acceptance, not the requested allocation. Slurm's server-side
[job-submit plugin](https://slurm.schedmd.com/job_submit_plugins.html) can modify the
request after the client assembles it. Inspect the active plugin and relevant code
branches when diagnosing rewrites; do not rely only on its header. A documented
unrouted field or implementation gap does not authorize bypassing site policy.
Take blocked hardware requests to the cluster administrators.

Validate known routing limits locally before staging. Keep separate tracked targets
for different hardware conditions and declare valid GPU counts on each target.
Minimum/maximum bounds must be positive integers and consistent. Do not silently
replace a target's GPU model or increase its count to get around an unreachable request.
Dated Empire-specific evidence belongs in [cluster-context.md](cluster-context.md).

For jobs whose approved resources or research comparability depend on placement:

1. Freeze the task, target, requested resources, expected physical GPU model, source
   revision, environment and hashes in a fresh packet. An untyped request still needs
   an explicit physical model expectation.
2. Persist submission intent before invoking `sbatch --hold`, then record its job ID.
   Capture submit-time stderr separately and retain scheduler notices verbatim in
   governed run provenance. These may explain a resource rewrite. Do not apply this
   logging rule to workload stderr, which may contain governed input text; do not
   publish unreviewed diagnostics.
3. Read `scontrol show job JOBID` and compare account, partition, QoS, constraints,
   typed GPU request, counts and resource/time limits with the packet. Normalize
   equivalent units, not different hardware. Missing required fields, lost GPU type
   or a mismatch leave the job held. Record the observation and reasons.
4. Call `scontrol release JOBID` only after the request comparison passes. Readback
   after ordinary submission is too late: an idle partition may start the job first.
   A queued match verifies the scheduled request, not the physical GPU.

Client precedence is command line, then environment, then script directives.
Use explicit flags and remove inherited `SBATCH_*` overrides from the submitter's
environment. `--export=NONE` controls the job environment, not what sbatch reads at
submission. Neither measure overrides a server-side plugin. See
[sbatch](https://slurm.schedmd.com/sbatch.html) and
[scontrol](https://slurm.schedmd.com/scontrol.html).

## Execution gate and provenance

Before the workload starts, check the packet and environment again on the allocated
compute node. Record the node name and actual GPU model, UUID, memory, architecture
and relevant driver/runtime identity. Verify every device the workload will use;
for multiple nodes, obtain evidence from each. Abort before the workload on a
mismatch or missing required evidence. This gate may consume startup allocation;
it does not replace held submission or authorize different hardware.

Pending jobs have no physical GPU evidence. In particular, `TresPerNode=gres:gpu:1`
names a count, not a model. Keep physical verification unknown until runtime evidence
arrives. For untyped scripts, copying the declared model into a parsed request is
not independent confirmation; a hash protects the declaration, not its truth.

Keep requested, scheduled and physical observations separate in run provenance.
A changed GPU model is a new benchmark hardware condition, even if memory capacity,
account and metrics look similar. Matching the requested GPU alone does not prove
comparability: compare against the baseline's recorded hardware and software.

## Parse actual scheduler output

Prefer structured output when the installed Slurm version supports it. Text output
contains compound keys such as `AllocNode:Sid`, `Socks/Node` and `NtasksPerN:B:S:C`.
A word-only key boundary can absorb the next field into `Partition` or `AllocTRES`.
For a whitelist of fields whose values contain no whitespace, tokenize with:

```python
pairs = re.findall(r"(?:^|\s)([A-Za-z][\w:/]*)=(\S*)", text)
```

This is not a parser for arbitrary free-text fields. Preserve empty and `(null)`
values and validate required fields explicitly. Test realistic multiline output
with `Partition=alpha AllocNode:Sid=...` on one line and
`AllocTRES=(null) Socks/Node=* NtasksPerN:B:S:C=0:0:*:*` on another. Cover both a
matching request that releases once and a rewrite that remains held; both tests
must assert `--hold` was actually used. Separately test runtime GPU verification.

## Preserve failed attempts

Keep blocked and cancelled packets with their original hashes, requested resources,
submit diagnostics, observations and disposition. Correct parser evidence in a new
observation while retaining the old record and its explanation. When cancellation
is authorized, capture needed live evidence first, then cancel and record the final
state; evidence retention does not require leaving an unusable job in the queue.
A corrected attempt gets a new run directory linked to its predecessor. Reconcile
job IDs and retry authority before another submission; the same hardware terms do
not by themselves authorize an extra attempt.
