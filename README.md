# Linux Admin Labs

Five Bash exercises for Linux administration, system inspection, and basic security checks. This portfolio demonstrates command-line automation relevant to junior Linux administration and infrastructure/security operations.

**Scope:** practical learning projects. The code shows implementation practice, without claiming production readiness or comprehensive security coverage.

## Labs and skills

| Lab | Current behavior | Skills demonstrated |
| --- | --- | --- |
| [Server health check](server-health-check/health_check.sh) | Prints hostname, current user, uptime, memory, root filesystem usage, and failed systemd services. | Command substitution, resource inspection, reporting. |
| [Service monitor](service-monitor/service_monitor.sh) | Checks one literal systemd unit's load state and activity; distinguishes query errors from inactivity. | Argument/dependency validation, conditionals, exit codes, stub-based tests. |
| [SSH log analyzer](ssh-log-analyzer/ssh_log_analyzer.sh) | Counts one SSH message pattern from a file or the journal and ranks extracted source addresses. | Journal queries, `awk`, deterministic sorting, fixture-based tests. |
| [User security audit](user-security-audit/user_audit.sh) | Lists selected local accounts, checks for duplicate UID 0 accounts, and reports password statuses matching `L`. | Parsing `/etc/passwd`, account inspection, loops. |
| [Server guard](server-guard/server_guard.sh) | Combines disk, service, and UID 0 checks; reports an SSH session-message count using local shell setup. | Combining checks, Boolean logic, status reporting. |

Each directory contains a standalone script. Start with the health check and service monitor, then explore log parsing, account inspection, and combined checks.

## Run safely

Use a disposable **Linux VM with Bash and a running systemd instance** for live system checks. On macOS, use a Linux VM such as UTM. The analyzer's file mode and the tests do not need systemd or journal permissions. Review the source before execution.

Dependencies include `systemctl`, `journalctl`, `free`, `uptime`, `hostname`, `passwd`, and standard text/core utilities (`awk`, `grep`, `sort`, `uniq`, `wc`, `tr`, `cat`, `df`, `whoami`).

```bash
git clone https://github.com/XBlasterX/linux-admin-labs.git
cd linux-admin-labs

# Syntax checks only; scripts are not executed.
git ls-files -z '*.sh' | xargs -0 -r -n1 bash -n

# Offline validation: no sudo, real service queries, or access to host logs.
bash tests/run.sh
bash ssh-log-analyzer/ssh_log_analyzer.sh tests/fixtures/ssh-mixed.log

# Run individually after reviewing the source.
bash server-health-check/health_check.sh
bash service-monitor/service_monitor.sh sshd
echo "$?"  # Read the monitor's exit code immediately.
bash ssh-log-analyzer/ssh_log_analyzer.sh
```

Replace `sshd` with an installed unit for the service monitor. Supply exactly one literal unit name, optionally ending in `.service`; options and glob patterns are rejected. Its exit codes are **0 = active**, **1 = not active**, **2 = invalid arguments or unit reported as not found**, **3 = missing dependency, query failure, or unexpected result**. It accepts `loaded` and `masked` load states, and maps `systemctl is-active` exit 3 to inactive. Other nonzero activity-query exits are errors. A failed service also counts as not active; this is not a full diagnosis of unit state.

The SSH analyzer accepts zero or one argument: no argument queries the journal once; a file argument reads only that regular, readable file. It requires `awk` and `sort`, plus `journalctl` only for live mode. Set `SSH_UNIT=ssh` on systems using that unit name (the default is `sshd`):

```bash
SSH_UNIT=ssh bash ssh-log-analyzer/ssh_log_analyzer.sh
```

File input must use message-only lines, equivalent to `journalctl -o cat`, without timestamps or syslog prefixes. The supported shape is `Connection closed by authenticating user USER ADDRESS port NUMBER ...`; other messages and incomplete lines are ignored. Addresses are treated as tokens, not validated as IP literals. Counts sort descending, with ties sorted lexically by address in the C locale. Output is now labeled **Matched SSH log messages**, not failed logins. Exit codes are **0 = analysis completed, including zero matches**, **2 = invalid arguments or unreadable/non-regular input**, **3 = missing command or read/analysis failure**. Failed journal reads discard partial stdout and produce no report.

Live mode needs journal-read permission; successful reads may still expose only the caller's accessible portion of the journal. Inspecting other users' password status generally requires root:

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

## Validation milestone

[Bash validation](.github/workflows/validate.yml) runs on pushes and pull requests using one Ubuntu 24.04 job. It checks Bash syntax for every tracked `.sh` file, then runs `bash tests/run.sh` as a non-root user. Checkout is pinned to a commit with read-only repository permissions and credentials are not persisted. No packages or test framework are required beyond Bash and standard Linux utilities.

The 32 checks cover:

- **Analyzer:** synthetic IPv4/IPv6 examples, repeated addresses and tied rankings, unrelated/malformed messages, empty input, paths with spaces, invalid/unreadable files, argument errors, default/custom journal units, partial journal failure, missing dependencies, and parser failure.
- **Monitor:** invalid arguments, active/inactive/masked/not-found responses, unavailable system bus, empty/unexpected load state, activity-query errors, and missing `systemctl`.

Tests use a temporary directory, a clean child environment, an allowlisted `PATH`, and local `systemctl`/`journalctl` stubs that never delegate to the host. They assert exit codes, stdout, diagnostics, and exact stub calls, including no journal calls in file mode and no activity query after a load-state error. Fixtures use synthetic usernames and documentation-range addresses. Run without sudo: the permission test must be unable to read a mode-000 file.

**Boundary:** these are fixture/stub integration tests, not live systemd integration tests. The health check, user audit, and server guard receive syntax checks only; their commands and shell startup files are never executed by the suite. There is no cross-distribution matrix or production-grade security coverage. A passing run does not establish host health, complete log access, or attack detection.

## Portability and limitations

- **Runtime:** native macOS and containers without systemd do not satisfy these assumptions. Command options and output formats vary across distributions.
- **SSH:** the analyzer defaults to `sshd` and accepts `SSH_UNIT`; server guard still hard-codes `sshd`. Neither has a journal time filter. The analyzer buffers live journal output in memory and supports only the message shape described above. This is not comprehensive failed-login detection; zero matches do not prove zero failures.
- **Accounts:** UID ≥ 1000 is only a heuristic for human users. The shell check matches only names ending in `bash`; the audit reads local `/etc/passwd`. Password-lock markers vary, and a locked password does not necessarily disable SSH keys.
- **Evidence:** the automated checks cover only the bounded behavior listed above. Reports and exit codes are not comprehensive health/security assessments.

## Possible next improvements

Replace server guard's personal aliases and startup-file sourcing with explicit dependencies; make thresholds and journal time ranges configurable; add ShellCheck in CI and real systemd checks in disposable VMs. These are future work, not part of the current validation milestone.
