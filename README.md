# Linux Admin Labs

Five Bash exercises for Linux administration, system inspection, and basic security checks. This portfolio demonstrates command-line automation relevant to junior Linux administration and infrastructure/security operations.

**Scope:** practical learning projects. The code shows implementation practice, without claiming production readiness or comprehensive security coverage.

## Labs and skills

| Lab | Current behavior | Skills demonstrated |
| --- | --- | --- |
| [Server health check](server-health-check/health_check.sh) | Prints hostname, current user, uptime, memory, root filesystem usage, and failed systemd services. | Command substitution, resource inspection, reporting. |
| [Service monitor](service-monitor/service_monitor.sh) | Checks a supplied systemd unit's load state and activity. | Argument validation, conditionals, exit codes. |
| [SSH log analyzer](ssh-log-analyzer/ssh_log_analyzer.sh) | Counts one SSH journal message pattern and ranks extracted source IPs. | Journal queries, filtering, `awk`, `sort`, `uniq`. |
| [User security audit](user-security-audit/user_audit.sh) | Lists selected local accounts, checks for duplicate UID 0 accounts, and reports password statuses matching `L`. | Parsing `/etc/passwd`, account inspection, loops. |
| [Server guard](server-guard/server_guard.sh) | Combines disk, service, and UID 0 checks; reports an SSH session-message count using local shell setup. | Combining checks, Boolean logic, status reporting. |

Each directory contains a standalone script. Start with the health check and service monitor, then explore log parsing, account inspection, and combined checks.

## Run safely

Use a disposable **Linux VM with Bash and a running systemd instance**. On macOS, use a Linux VM such as UTM. Review the source before execution.

Dependencies include `systemctl`, `journalctl`, `free`, `uptime`, `hostname`, `passwd`, and standard text/core utilities (`awk`, `grep`, `sort`, `uniq`, `wc`, `tr`, `cat`, `df`, `whoami`).

```bash
git clone https://github.com/XBlasterX/linux-admin-labs.git
cd linux-admin-labs

# Syntax checks only; scripts are not executed.
for script in */*.sh; do
    bash -n "$script" || break
done

# Run individually after reviewing the source.
bash server-health-check/health_check.sh
bash service-monitor/service_monitor.sh sshd
echo "$?"  # Read the monitor's exit code immediately.
bash ssh-log-analyzer/ssh_log_analyzer.sh
```

Replace `sshd` with an installed unit for the service monitor. Its exit codes are **0 = active**, **1 = not active**, **2 = missing argument or unit reported as not found**. Other systemctl failures are not comprehensively distinguished.

The SSH analyzer needs journal-read permission. Inspecting other users' password status generally requires root:

```bash
# Only in your own lab VM, after reviewing the script.
sudo bash user-security-audit/user_audit.sh
```

These four scripts inspect state without intentionally changing accounts or services. Use the least privilege necessary. Errors, inaccessible logs, and empty output are incomplete evidence. Redact usernames, hostnames, and IP addresses before sharing reports.

### Server guard: setup required

`server_guard.sh` sources `~/.bashrc`, executing its contents, and depends on two commands/aliases **not supplied here**:

- `disk`: second output row, fifth field must contain disk usage as a percentage.
- `user`: colon-separated account records with UID in the third field.

Review that startup file and both definitions, or adapt a local copy to explicit commands such as `df -P /` and `getent passwd` without sourcing shell startup files. Do not use sudo blindly: it can change the startup file and privileges.

Only after resolving these dependencies:

```bash
bash server-guard/server_guard.sh sshd
```

Use a service name without `.service`, which one check appends. Exit 0 means the combined condition passed; 1 means it did not. Unit-existence checking and error handling are limited; “ok” is not a security verdict.

## Portability and limitations

- **Runtime:** native macOS and containers without systemd do not satisfy these assumptions. Command options and output formats vary across distributions.
- **SSH:** both SSH-related scripts hard-code `sshd` (some systems use `ssh`) and have no journal time filter. The analyzer matches only `Connection closed by authenticating user` and assumes the seventh field is an IP address. This is not comprehensive failed-login detection; zero matches do not prove zero failures.
- **Accounts:** UID ≥ 1000 is only a heuristic for human users. The shell check matches only names ending in `bash`; the audit reads local `/etc/passwd`. Password-lock markers vary, and a locked password does not necessarily disable SSH keys.
- **Evidence:** no automated tests, CI workflow, or cross-distribution test matrix are currently included. Reports and exit codes are not comprehensive health/security assessments.

## Possible next improvements

Replace personal aliases with explicit dependencies; make units, thresholds, and journal time ranges configurable; add sample log fixtures, failure-path tests, and ShellCheck in CI.
