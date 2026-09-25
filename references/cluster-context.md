# Cluster context and sources

This reference separates dated cluster observations from reusable procedure. July–August 2026 observations were mainly Cornell; the 2026-09-11 routing evidence below came from live read-only scheduler and plugin inspection. The associated CUDA readiness job had not completed when this note was written.

Alpha GPU nodes were observed with H100 80GB and H200 141GB devices; Grace workloads used ARM aarch64, while Alpha GPU environments used x86. Beta guidance described ARM and Enroot. Verify current access, architecture, device memory, images and available features for the requested workload. Parameter count alone does not establish that training or inference fits: precision, optimizer, context length, batch size and parallelism matter.

Queue waits and CPU-node availability varied substantially across observations. Institutional account/partition equality, special test partitions, QoS priorities/caps, SU prices and annual allocations were historical configuration, not portable defaults. September public guidance describes project subaccounts and partition changes; the CCR guide addresses UB/SUNY users and cannot alone establish Cornell's live state.

The old BERT/SST-2 run recorded accuracy 0.9266 and 27 seconds of training on one H100. No complete lock, model/data revision or raw validation record accompanied it, so those numbers are illustrative rather than a reproducible baseline. Use explicit acceptance criteria and record new evidence.

## Alpha GPU routing observed 2026-09-11

Slurm 23.02.8 reported `JobSubmitPlugins=lua`. The inspected configuration was
`/cm/shared/apps/slurm/var/etc/slurm/slurm.conf`, with policy at
`/cm/shared/apps/slurm/var/etc/slurm/job_submit.lua` (header dated 2026-08-31).
The governed single-node per-node/total GPU requests behaved as follows:

| Request | Observed policy |
|---|---|
| One GPU, typed or untyped | Route to `alpha` with `rtx6000`; incompatible typed GPU requests become untyped |
| Two or more untyped GPUs | Exclude RTX nodes and clear a conflicting `rtx6000` constraint on fresh submission |
| Two or more typed H100/H200 GPUs | Leave unchanged by this routing rule |
| Two or more typed RTX GPUs | Reject |

The inspected implementation exempted `course` and `grace`; these are not alternatives
for bypassing the policy. Unrouted per-task/per-socket fields were documented as future
work, not approved escape routes. Refer blocked hardware requests to cluster administrators.
Re-verify the active plugin configuration and relevant implementation branches for the
requested partition, GPU syntax and node count; a header or this dated table is insufficient.
If implementation access is unavailable, obtain site confirmation and retain readback gates.

The current inventory placed H100 on `alphagpu01-18`, H200 on `alphagpu19-24`, and
RTX PRO 6000 Blackwell on `alphagpu51-54`. Cornell and Alpha shared the Hopper pool;
Alpha also included RTX. The Hopper nodes appeared in other institutional partitions,
so the pool was not exclusive. Hopper and Blackwell are separate hardware conditions,
regardless of GPU memory capacity. This observation does not establish the current queue,
future routing, or historical device identity; use retained per-run node/model evidence.

## Cornell notice 2026-09-18 (Beta rollout, Alpha migration)

Announced changes, not yet observed on the scheduler; verify each before changing a target:

- Beta project users have access to both Beta and Alpha. SU accounting on Beta starts 2026-10-01.
- Beta home directories: 100 GB quota enforced. Project storage `/projects/co/<project account>`, 8.333 SU per TB per month. Data not tied to an active Beta project should be offloaded.
- NVL72 jobs need at least 4 GPUs; automated termination of smaller jobs is planned. Single-GPU workloads move to the Alpha RTX 6000 Pro nodes. Four NVL72 trays for short single-GPU and interactive jobs are under consideration only.
- Alpha maintenance 2026-09-21: institution partitions (`cornell`, `nyu`, ...) are replaced by hardware-tier partitions `alpha` and `grace`, and every submission needs an explicit `--account`. Any tracked target that says `partition: cornell` breaks at that point; the notice implied the QoS lane stays on the current account. Superseded: the QoS tiers moved to the project account ([observed 2026-09-21](#alpha-migration-observed-2026-09-21)).
- A Rootly status dashboard publishes incidents; an SU balance dashboard is planned, and PIs see usage on ColdFront.
- NVIDIA office hours Thursdays 14:00 to 15:00 ET (Teams link and survey in the notice).

Full text: [notice_2026-09-18.md](notice_2026-09-18.md). The attached guide is stored as [beta_nvl72_job_submission_guide.pdf](beta_nvl72_job_submission_guide.pdf) and distilled in [beta.md](beta.md).

## Alpha migration observed 2026-09-21

- Every queued and running job ended `NODE_FAIL` at the maintenance. Checkpoints on Lustre survived; jobs resume from them through new submissions.
- Partition `cornell` is gone. H200 nodes `alphagpu19-24` are on `alpha` (gres `nvidia_h200`, feature `h200`); `alpha` showed `AllowAccounts=ALL` and `AllowQos=ALL`.
- The migration moved the `priority`, `standard`, `long` and `test` QoS from the institution account to the project account (default QoS `standard`). The institution account kept only `burst`. Jobs resubmitted under the institution account pended with `InvalidQOS`.
- Priority QoS showed `MaxWall=1-00:00:00` in `sacctmgr`, but jobs requesting 21 to 24 h pended with `QOSMaxWallDurationPerJobLimit`; every running priority job was at most 12 h (observed 2026-09-20). This applies to Alpha only; Beta priority is planned at its listed 24 h ([beta.md](beta.md#qos-tiers)). QoS `standard` allowed 2 days at half the priority; `long` allowed 7 days.

After any site change, list `sacctmgr show assoc user=$USER` and confirm which account carries each QoS on the target partition before editing targets or resubmitting.

## Primary sources

- [Empire support/onboarding](https://empireai.freshdesk.com/support/home)
- [CCR Empire guide](https://docs.ccr.buffalo.edu/en/latest/howto/empireai/)
- [Alpha job submission and QoS](https://empireai.freshdesk.com/support/solutions/articles/157000374474-alpha-job-submission-and-qos-overview)
- [Alpha storage](https://empireai.freshdesk.com/support/solutions/articles/157000175046)
- [Service units and allocations](https://empireai.freshdesk.com/support/solutions/articles/157000363467)
- [Acknowledgement/citation requirements](https://empireai.freshdesk.com/support/solutions/articles/157000359451)
- [OpenSSH ControlPersist](https://man.openbsd.org/ssh_config#ControlPersist)
- [Cornell notice 2026-09-18](notice_2026-09-18.md) and its attachment, the [Beta NVL72 job submission guide](beta_nvl72_job_submission_guide.pdf)
- [Slurm sbatch --signal and --requeue](https://slurm.schedmd.com/sbatch.html)
- [NGC PyTorch containers](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch)

Use current institutional citation requirements for publications using Empire resources. Verify support schedules and sharing/ACL policy when needed instead of preserving them as fixed personal-skill rules.
