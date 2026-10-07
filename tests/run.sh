#!/bin/bash
# Small integration tests; only allowlisted text tools and local stubs enter PATH.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
bin="$tmp/bin"
mkdir -p "$bin" "$tmp/home"
for tool in awk sort cat; do
    ln -s "$(command -v "$tool")" "$bin/$tool"
done
cp "$root/tests/stubs/systemctl.sh" "$bin/systemctl"
cp "$root/tests/stubs/journalctl.sh" "$bin/journalctl"
chmod +x "$bin/systemctl" "$bin/journalctl"

analyzer="$root/ssh-log-analyzer/ssh_log_analyzer.sh"
monitor="$root/service-monitor/service_monitor.sh"
fixture="$root/tests/fixtures/ssh-mixed.log"
expected_report=$(< "$root/tests/fixtures/ssh-mixed.expected")
empty_report='Matched SSH log messages: 0'
mode=unexpected
unit=sshd
ssh_unit=''
count=0

# name, exit code, complete stdout, stderr substring (or empty), exact call trace,
# then the script and its arguments. Child commands cannot reach host systemd.
check() {
    local name=$1 expected_status=$2 expected_stdout=$3 expected_error=$4 expected_trace=$5
    local status=0
    shift 5
    : > "$tmp/trace"
    if env -i PATH="$bin" HOME="$tmp/home" LC_ALL=C \
        STUB_CASE="$mode" EXPECTED_UNIT="$unit" SSH_UNIT="$ssh_unit" \
        FIXTURE="$fixture" STUB_TRACE="$tmp/trace" \
        /bin/bash "$@" > "$tmp/stdout" 2> "$tmp/stderr"; then
        status=0
    else
        status=$?
    fi
    if [[ $status != "$expected_status" || $(< "$tmp/stdout") != "$expected_stdout" ||
        $(< "$tmp/trace") != "$expected_trace" ]] ||
        { [[ -z "$expected_error" ]] && [[ -s "$tmp/stderr" ]]; } ||
        { [[ -n "$expected_error" ]] && [[ $(< "$tmp/stderr") != *"$expected_error"* ]]; }; then
        printf 'FAIL: %s (exit %s, expected %s)\n' "$name" "$status" "$expected_status" >&2
        printf 'stdout:\n%s\nstderr:\n%s\ntrace:\n%s\n' \
            "$(< "$tmp/stdout")" "$(< "$tmp/stderr")" "$(< "$tmp/trace")" >&2
        exit 1
    fi
    count=$((count + 1))
    printf 'ok %d - %s\n' "$count" "$name"
}

# File mode must not call journalctl, even when it is available on PATH.
check 'mixed messages, IPv4/IPv6, tied counts and ignored patterns' 0 "$expected_report" '' '' "$analyzer" "$fixture"
check 'unmatched messages are not called failed logins' 0 "$empty_report" '' '' "$analyzer" "$root/tests/fixtures/ssh-no-matches.log"
: > "$tmp/empty.log"
check 'empty input' 0 "$empty_report" '' '' "$analyzer" "$tmp/empty.log"
cp "$fixture" "$tmp/messages with spaces.log"
check 'quoted input path' 0 "$expected_report" '' '' "$analyzer" "$tmp/messages with spaces.log"
check 'missing file' 2 '' 'readable regular message file' '' "$analyzer" "$tmp/missing.log"
check 'directory is not a log file' 2 '' 'readable regular message file' '' "$analyzer" "$tmp"
cp "$fixture" "$tmp/unreadable.log"
chmod 000 "$tmp/unreadable.log"
if [[ -r "$tmp/unreadable.log" ]]; then
    echo 'Permission test needs a user that cannot read mode-000 files. Run without sudo.' >&2
    exit 1
fi
check 'unreadable file' 2 '' 'readable regular message file' '' "$analyzer" "$tmp/unreadable.log"
check 'extra analyzer arguments' 2 '' 'Usage:' '' "$analyzer" "$fixture" extra

# Only our stubs can satisfy the live-mode dependency.
mode=journal-ok
journal_trace='-u sshd --no-pager -o cat'
check 'one journal read with default unit' 0 "$expected_report" '' "$journal_trace" "$analyzer"
unit=ssh
ssh_unit=ssh
check 'configurable SSH unit' 0 "$expected_report" '' '-u ssh --no-pager -o cat' "$analyzer"
unit=sshd
ssh_unit=''
mode=journal-empty
check 'empty journal' 0 "$empty_report" '' "$journal_trace" "$analyzer"
mode=journal-failure
check 'journal failure discards partial data' 3 '' 'could not read SSH journal' "$journal_trace" "$analyzer"

mv "$bin/journalctl" "$tmp/journalctl.saved"
check 'missing journalctl' 3 '' 'required command not found: journalctl' '' "$analyzer"
check 'file mode needs no journalctl' 0 "$expected_report" '' '' "$analyzer" "$fixture"
mv "$tmp/journalctl.saved" "$bin/journalctl"
for tool in awk sort; do
    mv "$bin/$tool" "$tmp/$tool.saved"
    check "missing $tool" 3 '' "required command not found: $tool" '' "$analyzer" "$fixture"
    mv "$tmp/$tool.saved" "$bin/$tool"
done
mv "$bin/awk" "$tmp/awk.saved"
printf '#!/bin/bash\nexit 7\n' > "$bin/awk"
chmod +x "$bin/awk"
check 'parser failure is not an empty result' 3 '' 'could not analyze message file' '' "$analyzer" "$fixture"
rm "$bin/awk"
mv "$tmp/awk.saved" "$bin/awk"

mode=active
unit=demo.service
show_trace='show --property=LoadState --value -- demo.service'
activity_trace="$show_trace"$'\nis-active --quiet -- demo.service'
heading=$'service monitor\nservice: demo.service\nstatus: '
check 'missing service argument' 2 '' 'one literal service name required' '' "$monitor"
check 'empty service argument' 2 '' 'one literal service name required' '' "$monitor" ''
check 'extra service argument' 2 '' 'one literal service name required' '' "$monitor" demo.service extra
check 'option is not a service' 2 '' 'one literal service name required' '' "$monitor" --help
check 'pattern is not a single service' 2 '' 'one literal service name required' '' "$monitor" 'demo*'
check 'active service' 0 "${heading}ACTIVE" '' "$activity_trace" "$monitor" "$unit"
mode=inactive
check 'inactive service' 1 "${heading}INACTIVE" '' "$activity_trace" "$monitor" "$unit"
mode=masked
check 'masked inactive service' 1 "${heading}INACTIVE" '' "$activity_trace" "$monitor" "$unit"
mode=not-found
check 'missing unit stops before activity query' 2 "${heading}NOT FOUND" '' "$show_trace" "$monitor" "$unit"
mode=show-failure
check 'load query failure stops before activity query' 3 '' 'could not query load state' "$show_trace" "$monitor" "$unit"
for mode in empty-state bad-state; do
    check "unexpected load state: $mode" 3 '' 'unexpected load state' "$show_trace" "$monitor" "$unit"
done
for mode in activity-failure unknown; do
    check "activity query error: $mode" 3 '' 'could not query activity' "$activity_trace" "$monitor" "$unit"
done
mv "$bin/systemctl" "$tmp/systemctl.saved"
check 'missing systemctl' 3 '' 'required command not found: systemctl' '' "$monitor" "$unit"

printf 'All %d tests passed. No live systemd or journal calls were used.\n' "$count"
