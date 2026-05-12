#!/usr/bin/env bats
#
# Feature: shipnode-run, Property 1: context preamble always included
#
# **Validates: Requirements 1.2, 2.4**
#
# Property 1: Le préambule de contexte est toujours inclus dans la commande SSH
#
# For any non-empty remote command — regardless of mode (interactive or not) —
# the SSH command string constructed by the Runner SHALL always contain:
#   - "cd $REMOTE_PATH/current"   (working-directory preamble)
#   - "shared/.env"               (environment-file sourcing preamble)
#
# Test strategy:
#   - Source run.sh with mocked dependencies (load_config, ssh_cmd, error, warn)
#   - Mock ssh_cmd to capture the full argument string passed to it
#   - Call cmd_run for each command in a representative set covering all
#     equivalence classes:
#       Class A — non-shell commands (no --tty)
#       Class B — known shells (auto-detected interactive mode)
#       Class C — any command with --tty (forced interactive mode)
#       Class D — known shell + --tty (no double-activation side effects)
#   - Assert that every captured SSH invocation contains both preamble fragments
#
# Minimum 20 iterations covering all equivalence classes.

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve project root relative to this test file
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    RUN_SH="$PROJECT_ROOT/lib/commands/run.sh"

    # Temporary directory for capture artifacts
    TEST_TMP="$(mktemp -d)"

    # File where the mock ssh_cmd records its arguments
    SSH_CMD_CAPTURE_FILE="$TEST_TMP/ssh_invocations.txt"
    export SSH_CMD_CAPTURE_FILE TEST_TMP PROJECT_ROOT RUN_SH

    # Minimal config variables required by cmd_run / load_config
    SSH_USER="testuser"
    SSH_HOST="testhost.example.com"
    SSH_PORT="22"
    REMOTE_PATH="/var/www/myapp"
    export SSH_USER SSH_HOST SSH_PORT REMOTE_PATH

    # Source core helpers if present (provides error/warn/info/success stubs)
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/lib/core.sh" 2>/dev/null || true

    # Override ssh_cmd: record all arguments, return 0
    ssh_cmd() {
        echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
        return 0
    }
    export -f ssh_cmd

    # Stub load_config: variables already exported above
    load_config() {
        : # no-op — config already in environment
    }
    export -f load_config

    # Source the module under test (defines cmd_run and helpers)
    # shellcheck source=/dev/null
    source "$RUN_SH"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# Helper: invoke cmd_run in a subshell and capture the SSH invocation.
#
# The subshell ensures that `exit` calls inside _run_exec do not abort the
# bats process. All exported functions and variables are inherited.
# ---------------------------------------------------------------------------
run_cmd_run() {
    # Reset capture file for this invocation
    > "$SSH_CMD_CAPTURE_FILE"
    (
        # Re-declare overrides inside the subshell
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
# Helper: assert that the last SSH invocation contains a given substring
# ---------------------------------------------------------------------------
assert_ssh_contains() {
    local expected="$1"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
    if [[ "$invocation" != *"$expected"* ]]; then
        echo "Expected SSH invocation to contain: '$expected'" >&2
        echo "Actual invocation: '$invocation'" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Helper: assert both preamble fragments are present in the SSH invocation
# ---------------------------------------------------------------------------
assert_preamble_present() {
    assert_ssh_contains "cd $REMOTE_PATH/current" || return 1
    assert_ssh_contains "shared/.env"             || return 1
}

# ===========================================================================
# CLASS A — Non-shell commands without --tty (non-interactive mode)
# The preamble must be present regardless of the -T flag being used.
# ===========================================================================

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-01/20]: 'node script.js' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "node script.js"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-02/20]: 'npm run migrate' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "npm run migrate"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-03/20]: 'echo hello' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "echo hello"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-04/20]: 'ls -la' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "ls -la"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-05/20]: 'cat /etc/os-release' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "cat /etc/os-release"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-06/20]: 'python3 manage.py migrate' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "python3 manage.py migrate"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-07/20]: 'node -e console.log(process.env.NODE_ENV)' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "node -e 'console.log(process.env.NODE_ENV)'"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-08/20]: 'pm2 list' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "pm2 list"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-09/20]: 'df -h' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "df -h"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [A-10/20]: 'top -b -n1' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "top -b -n1"
    assert_preamble_present
}

# ===========================================================================
# CLASS B — Known shells (auto-detected interactive mode, -t flag)
# The preamble must be present even when a PTY is allocated.
# ===========================================================================

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-11/20]: 'bash' (known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "bash"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-12/20]: 'sh' (known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "sh"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-13/20]: 'zsh' (known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "zsh"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-14/20]: 'fish' (known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "fish"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-15/20]: '/bin/bash' (absolute path, known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "/bin/bash"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [B-16/20]: '/usr/bin/zsh' (absolute path, known shell) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run "/usr/bin/zsh"
    assert_preamble_present
}

# ===========================================================================
# CLASS C — Any command with --tty (forced interactive mode)
# The preamble must be present when --tty is used with non-shell commands.
# ===========================================================================

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [C-17/20]: '--tty top' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "top"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [C-18/20]: '--tty htop' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "htop"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [C-19/20]: '--tty vim /etc/hosts' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "vim /etc/hosts"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [C-20/20]: '--tty node script.js' — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "node script.js"
    assert_preamble_present
}

# ===========================================================================
# CLASS D — Known shell + --tty (no double-activation side effects)
# The preamble must still be present; no regression from dual activation.
# ===========================================================================

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [D-bonus]: '--tty bash' (shell + forced TTY) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "bash"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [D-bonus]: '--tty zsh' (shell + forced TTY) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "zsh"
    assert_preamble_present
}

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [D-bonus]: '--tty fish' (shell + forced TTY) — preamble present" {
    # Validates: Requirements 1.2, 2.4
    run_cmd_run --tty "fish"
    assert_preamble_present
}

# ===========================================================================
# Parametric sweep — loop over all equivalence classes in a single test
# Makes the universal property explicit and easy to read in CI output.
# ===========================================================================

# Feature: shipnode-run, Property 1: context preamble always included
@test "Property 1 [sweep]: all 20+ representative commands contain preamble" {
    # Validates: Requirements 1.2, 2.4
    local failures=0

    # Class A — non-shell, non-interactive
    local non_shell_cmds=(
        "node script.js"
        "npm run migrate"
        "echo hello"
        "ls -la"
        "cat /etc/os-release"
        "python3 manage.py migrate"
        "pm2 list"
        "df -h"
        "top -b -n1"
    )

    # Class B — known shells (auto-detected interactive)
    local shell_cmds=(
        "bash"
        "sh"
        "zsh"
        "fish"
        "/bin/bash"
        "/usr/bin/zsh"
    )

    # Class C — forced interactive via --tty (tested as separate args)
    # These are handled below with the --tty prefix

    for cmd in "${non_shell_cmds[@]}"; do
        > "$SSH_CMD_CAPTURE_FILE"
        ( ssh_cmd() { echo "$@" >> "$SSH_CMD_CAPTURE_FILE"; return 0; }
          load_config() { :; }
          cmd_run "$cmd" ) 2>/dev/null
        local inv
        inv="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
        if [[ "$inv" != *"cd $REMOTE_PATH/current"* ]]; then
            echo "FAIL [non-shell '$cmd']: missing 'cd \$REMOTE_PATH/current'" >&2
            failures=$((failures + 1))
        fi
        if [[ "$inv" != *"shared/.env"* ]]; then
            echo "FAIL [non-shell '$cmd']: missing 'shared/.env'" >&2
            failures=$((failures + 1))
        fi
    done

    for cmd in "${shell_cmds[@]}"; do
        > "$SSH_CMD_CAPTURE_FILE"
        ( ssh_cmd() { echo "$@" >> "$SSH_CMD_CAPTURE_FILE"; return 0; }
          load_config() { :; }
          cmd_run "$cmd" ) 2>/dev/null
        local inv
        inv="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
        if [[ "$inv" != *"cd $REMOTE_PATH/current"* ]]; then
            echo "FAIL [shell '$cmd']: missing 'cd \$REMOTE_PATH/current'" >&2
            failures=$((failures + 1))
        fi
        if [[ "$inv" != *"shared/.env"* ]]; then
            echo "FAIL [shell '$cmd']: missing 'shared/.env'" >&2
            failures=$((failures + 1))
        fi
    done

    # Class C — --tty with non-shell commands
    local tty_cmds=("top" "htop" "vim /etc/hosts" "node script.js" "npm run start")
    for cmd in "${tty_cmds[@]}"; do
        > "$SSH_CMD_CAPTURE_FILE"
        ( ssh_cmd() { echo "$@" >> "$SSH_CMD_CAPTURE_FILE"; return 0; }
          load_config() { :; }
          cmd_run --tty "$cmd" ) 2>/dev/null
        local inv
        inv="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
        if [[ "$inv" != *"cd $REMOTE_PATH/current"* ]]; then
            echo "FAIL [--tty '$cmd']: missing 'cd \$REMOTE_PATH/current'" >&2
            failures=$((failures + 1))
        fi
        if [[ "$inv" != *"shared/.env"* ]]; then
            echo "FAIL [--tty '$cmd']: missing 'shared/.env'" >&2
            failures=$((failures + 1))
        fi
    done

    [ "$failures" -eq 0 ]
}
