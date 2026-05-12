#!/usr/bin/env bats
#
# Feature: shipnode-run, Property 3: SSH TTY flag matches detected mode
#
# Validates: Requirements 1.5, 2.3
#
# Property: For any remote command, if the mode is non-interactive then the SSH
# flag used SHALL be -T; if the mode is interactive then the SSH flag SHALL be -t.
#
# Test strategy:
#   - Non-interactive class: non-shell commands without --tty  → expect -T
#   - Interactive class A:   known shells (bash, sh, zsh, fish) → expect -t
#   - Interactive class B:   any command with --tty flag        → expect -t
#   - Interactive class C:   known shell + --tty (no side-effects) → expect -t
#
# Minimum 20 iterations covering all equivalence classes.

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve project root relative to this test file
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

    # Temporary directory for mock artifacts
    TEST_TMP="$(mktemp -d)"

    # Write a mock ssh_cmd that records its arguments and exits 0
    cat > "$TEST_TMP/ssh_cmd_mock.sh" << 'MOCK'
#!/usr/bin/env bash
# Mock ssh_cmd: record all arguments to a capture file, then exit 0
echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
exit 0
MOCK
    chmod +x "$TEST_TMP/ssh_cmd_mock.sh"

    # Capture file for SSH invocations
    SSH_CMD_CAPTURE_FILE="$TEST_TMP/ssh_invocations.txt"
    export SSH_CMD_CAPTURE_FILE

    # Minimal shipnode.conf variables required by load_config / cmd_run
    SSH_USER="testuser"
    SSH_HOST="testhost.example.com"
    SSH_PORT="22"
    REMOTE_PATH="/var/www/myapp"
    export SSH_USER SSH_HOST SSH_PORT REMOTE_PATH

    # Source core helpers (error, warn, info, success, ssh_cmd)
    # We override ssh_cmd after sourcing so the mock takes effect.
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/lib/core.sh" 2>/dev/null || true

    # Override ssh_cmd with the mock
    ssh_cmd() {
        echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
        return 0
    }
    export -f ssh_cmd

    # Stub load_config so it does not try to read shipnode.conf from disk
    load_config() {
        : # variables already exported above
    }
    export -f load_config

    # Source the module under test
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/lib/commands/run.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# Helper: run cmd_run in a subshell and return its exit code
# The subshell inherits all exported functions and variables.
# ---------------------------------------------------------------------------
run_cmd_run() {
    # Reset capture file for this invocation
    > "$SSH_CMD_CAPTURE_FILE"
    # Run in subshell so exit calls do not abort the test
    (
        # Re-export overrides inside subshell
        ssh_cmd() {
            echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
            return 0
        }
        load_config() { :; }
        cmd_run "$@"
    )
    return $?
}

# ---------------------------------------------------------------------------
# Helper: assert that the last SSH invocation contains a given flag
# ---------------------------------------------------------------------------
assert_ssh_flag() {
    local expected_flag="$1"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
    if [[ "$invocation" != *"$expected_flag"* ]]; then
        echo "Expected SSH flag '$expected_flag' not found in invocation:"
        echo "  $invocation"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Helper: assert that the last SSH invocation does NOT contain a given flag
# ---------------------------------------------------------------------------
refute_ssh_flag() {
    local unexpected_flag="$1"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
    if [[ "$invocation" == *"$unexpected_flag"* ]]; then
        echo "Unexpected SSH flag '$unexpected_flag' found in invocation:"
        echo "  $invocation"
        return 1
    fi
}

# ===========================================================================
# CLASS 1 — Non-interactive commands (no --tty, not a known shell)
# Expected: -T present, -t absent
# ===========================================================================

@test "Property 3 [non-interactive]: 'node script.js' uses -T" {
    run_cmd_run "node script.js"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'npm run migrate' uses -T" {
    run_cmd_run "npm run migrate"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'echo hello' uses -T" {
    run_cmd_run "echo hello"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'ls -la' uses -T" {
    run_cmd_run "ls -la"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'cat /etc/os-release' uses -T" {
    run_cmd_run "cat /etc/os-release"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'top -b -n1' uses -T" {
    run_cmd_run "top -b -n1"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'python3 manage.py migrate' uses -T" {
    run_cmd_run "python3 manage.py migrate"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'node -e console.log(1)' uses -T" {
    run_cmd_run "node -e 'console.log(1)'"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'pm2 list' uses -T" {
    run_cmd_run "pm2 list"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

@test "Property 3 [non-interactive]: 'df -h' uses -T" {
    run_cmd_run "df -h"
    assert_ssh_flag " -T "
    refute_ssh_flag " -t "
}

# ===========================================================================
# CLASS 2A — Known shells (auto-detected interactive mode)
# Expected: -t present, -T absent
# ===========================================================================

@test "Property 3 [interactive/shell]: 'bash' uses -t" {
    run_cmd_run "bash"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell]: 'sh' uses -t" {
    run_cmd_run "sh"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell]: 'zsh' uses -t" {
    run_cmd_run "zsh"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell]: 'fish' uses -t" {
    run_cmd_run "fish"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell]: '/bin/bash' (full path) uses -t" {
    run_cmd_run "/bin/bash"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell]: '/usr/bin/zsh' (full path) uses -t" {
    run_cmd_run "/usr/bin/zsh"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

# ===========================================================================
# CLASS 2B — Any command with --tty flag (forced interactive mode)
# Expected: -t present, -T absent
# ===========================================================================

@test "Property 3 [interactive/--tty]: '--tty top' uses -t" {
    run_cmd_run --tty "top"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/--tty]: '--tty htop' uses -t" {
    run_cmd_run --tty "htop"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/--tty]: '--tty vim /etc/hosts' uses -t" {
    run_cmd_run --tty "vim /etc/hosts"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/--tty]: '--tty node script.js' uses -t" {
    run_cmd_run --tty "node script.js"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/--tty]: '--tty npm run start' uses -t" {
    run_cmd_run --tty "npm run start"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

# ===========================================================================
# CLASS 2C — Known shell + --tty (no double-activation side effects)
# Expected: -t present, -T absent (same as interactive, no regression)
# ===========================================================================

@test "Property 3 [interactive/shell+--tty]: '--tty bash' uses -t (no side effects)" {
    run_cmd_run --tty "bash"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}

@test "Property 3 [interactive/shell+--tty]: '--tty zsh' uses -t (no side effects)" {
    run_cmd_run --tty "zsh"
    assert_ssh_flag " -t "
    refute_ssh_flag " -T "
}
