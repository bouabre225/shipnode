#!/usr/bin/env bats
#
# Feature: shipnode-run, Property 2: exit code propagated exactly
#
# Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
#
# Property 2: Le code de retour distant est propagé exactement
#   For any exit code N (0–255) returned by the remote command via SSH,
#   the shipnode run process SHALL exit with that same code N, unchanged.
#
# Strategy: mock ssh_cmd to return each code in {0, 1, 2, 127, 128, 130, 255},
#   source run.sh, call cmd_run, and assert the exit code matches exactly.

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve project root relative to this test file
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    RUN_SH="$PROJECT_ROOT/lib/commands/run.sh"

    # Create a temporary working directory for each test
    TEST_DIR="$(mktemp -d)"

    # Write a minimal shipnode.conf so load_config does not abort
    cat > "$TEST_DIR/shipnode.conf" << 'EOF'
APP_TYPE=backend
SSH_USER=deploy
SSH_HOST=example.com
SSH_PORT=22
REMOTE_PATH=/var/www/myapp
PM2_APP_NAME=myapp
BACKEND_PORT=3000
EOF

    # Change into the temp dir so load_config finds shipnode.conf
    cd "$TEST_DIR"

    # Stub out functions that have side-effects we do not want during unit tests
    # load_config: source the local shipnode.conf without SSH multiplex
    load_config() {
        source "$TEST_DIR/shipnode.conf"
        SSH_PORT="${SSH_PORT:-22}"
        REMOTE_PATH="${REMOTE_PATH:-/var/www/myapp}"
    }

    # start_ssh_multiplex: no-op
    start_ssh_multiplex() { :; }

    # info / warn / error: silent during tests (error still exits)
    info()    { :; }
    warn()    { :; }
    error()   { echo "ERROR: $*" >&2; exit 1; }
    success() { :; }

    # Export stubs so subshells see them
    export -f load_config start_ssh_multiplex info warn error success
    export TEST_DIR PROJECT_ROOT RUN_SH
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# Helper: run cmd_run with a mocked ssh_cmd that exits with a given code
#
# Usage: run_with_exit_code <expected_code> [cmd_run_args...]
#
# We source run.sh inside a subshell so that each test gets a clean slate
# and the `exit` call inside _run_exec does not kill the bats process.
# ---------------------------------------------------------------------------

_invoke_cmd_run_with_ssh_exit() {
    local ssh_exit_code="$1"
    shift
    local cmd_run_args=("$@")

    # Run in a subshell so exit propagates as the subshell's exit code
    (
        # Re-apply stubs inside the subshell
        load_config() {
            source "$TEST_DIR/shipnode.conf"
            SSH_PORT="${SSH_PORT:-22}"
            REMOTE_PATH="${REMOTE_PATH:-/var/www/myapp}"
        }
        start_ssh_multiplex() { :; }
        info()    { :; }
        warn()    { :; }
        error()   { echo "ERROR: $*" >&2; exit 1; }
        success() { :; }

        # Mock ssh_cmd: ignore all arguments, just exit with the desired code
        ssh_cmd() { return "$ssh_exit_code"; }

        # Source the implementation under test
        source "$RUN_SH"

        # Invoke cmd_run; its exit $? will become the subshell exit code
        cmd_run "${cmd_run_args[@]}"
    )
}

# ---------------------------------------------------------------------------
# Property 2 tests — one @test per exit code in {0, 1, 2, 127, 128, 130, 255}
# ---------------------------------------------------------------------------

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 0 is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 0 "echo hello"
    [ "$status" -eq 0 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 1 is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 1 "false"
    [ "$status" -eq 1 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 2 is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 2 "grep --bad-flag"
    [ "$status" -eq 2 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 127 (command not found) is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 127 "nonexistent_command"
    [ "$status" -eq 127 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 128 is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 128 "some_command"
    [ "$status" -eq 128 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 130 (SIGINT) is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    run _invoke_cmd_run_with_ssh_exit 130 "some_command"
    [ "$status" -eq 130 ]
}

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: exit code 255 is propagated unchanged" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    # Note: 255 is also the SSH connection-failure code; the runner must
    # still propagate it exactly (the warn() about connection params is
    # acceptable as a side-effect, but the exit code must be 255).
    run _invoke_cmd_run_with_ssh_exit 255 "some_command"
    [ "$status" -eq 255 ]
}

# ---------------------------------------------------------------------------
# Parametric sweep — loop over all codes to make the property explicit
# ---------------------------------------------------------------------------

# Feature: shipnode-run, Property 2: exit code propagated exactly
@test "Property 2: all codes in {0,1,2,127,128,130,255} are propagated exactly" {
    # Validates: Requirements 1.4, 2.5, 3.4, 4.2, 4.3
    local exit_codes=(0 1 2 127 128 130 255)
    local failures=0

    for code in "${exit_codes[@]}"; do
        run _invoke_cmd_run_with_ssh_exit "$code" "echo test"
        local actual="$status"
        if [ "$actual" -ne "$code" ]; then
            echo "FAIL: expected exit code $code, got $actual" >&2
            failures=$((failures + 1))
        fi
    done

    [ "$failures" -eq 0 ]
}
