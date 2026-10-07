# Empire AI access

Request an account through the institution's current onboarding process. Use the official FIDO/support instructions for password and MFA enrollment; never route enrollment secrets through an agent transcript.

Merge the matching host block from [assets/ssh_config](assets/ssh_config) into the existing SSH configuration without replacing unrelated hosts. Set the actual username and create a protected socket directory (`mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets`). Preserve working organization authentication settings rather than overriding them from historical observations.

The template retains the previously used password/keyboard-interactive route and disables public-key attempts for this host. Verify current onboarding guidance if that route no longer works. A human performs interactive login in a real terminal with `ssh empire`; agents use the established connection.

`ControlPersist 48h` means up to 48 hours of idle persistence with no client connections, not expiry 48 hours after login. Frequent clients can keep the connection active longer, and server policy, network failure, or sleep can end it earlier. A shorter idle setting is not a fixed reauthentication policy. Configuration edits affect a newly established master; do not kill a shared master to apply them without authorization.

Also merge the `empire-batch` block: same socket path, `ControlMaster no`, `BatchMode yes`, `ProxyCommand /usr/bin/false`. Check that `ssh -G empire-batch` and `ssh -G empire` print the same `controlpath`. With no socket, `ssh empire-batch true` must fail in milliseconds. Verify the existing connection with `ssh -O check empire`, then use `ssh empire-batch ...` and `rsync ... empire-batch:path` for automation. Follow authmux's transport check if configured for this context. If the connection is unavailable, stop that operation and use the approved human login handoff.

During authorized scheduler setup, inspect the full account associations and current partitions/QoS. Record account, partition, and writable storage root independently; do not treat an association listing as proof of storage ownership. Explicitly resolve ambiguous projects before submission. SSH success establishes access only. Optional workload validation is described in [references/jobs.md](references/jobs.md).
