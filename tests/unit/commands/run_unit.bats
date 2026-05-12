#!/usr/bin/env bats
#
# Feature: shipnode-run — Unit tests for argument parsing and error cases
#
# Validates: Requirements 2.1, 2.2, 3.1, 3.2, 3.3
#
# Covers:
#   - `shipnode run` with no argument → exit 1 + usage message on stderr
#   - `shipnode run --tty "top"` → interactive mode activated, -t flag used
#   - `shipnode run "node -e 'console.log(1)'"` → command transmitted intact, -T flag used
#   - SSH failure (mock ssh_cmd returning 255) → warn() output contains SSH_USER, SSH_HOST, SSH_PORT
#   - .env absent on server (mock remote returning sourcing error) → warning on stderr, execution continues
#   - `shipnode run bash` → auto-detected as interactive, -t flag used

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve project root relative to this test file (tests/unit/commands/)
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    RUN_SH="$PROJECT_ROOT/lib/commands/run.sh"

    # Temporary directory for capture artifacts
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

    # Capture files for mock output
    SSH_CMD_CAPTURE_FILE="$TEST_DIR/ssh_invocations.txt"
    WARN_CAPTURE_FILE="$TEST_DIR/warn_output.txt"
    ERROR_CAPTURE_FILE="$TEST_DIR/error_output.txt"

    export TEST_DIR PROJECT_ROOT RUN_SH
    export SSH_CMD_CAPTURE_FILE WARN_CAPTURE_FILE ERROR_CAPTURE_FILE

    # Config variables (mirrors shipnode.conf)
    SSH_USER="deploy"
    SSH_HOST="example.com"
    SSH_PORT="22"
    REMOTE_PATH="/var/www/myapp"
    export SSH_USER SSH_HOST SSH_PORT REMOTE_PATH

    # Stub load_config: variables already exported above
    load_config() {
        SSH_USER="deploy"
        SSH_HOST="example.com"
        SSH_PORT="22"
        REMOTE_PATH="/var/www/myapp"
    }

    # Stub start_ssh_multiplex: no-op
    start_ssh_multiplex() { :; }

    # Stub info/success: silent
    info()    { :; }
    success() { :; }

    # Stub warn: record output to capture file AND stderr (matches real behaviour)
    warn() {
        echo "$*" >> "$WARN_CAPTURE_FILE"
        echo "⚠ $*" >&2
    }

    # Stub error: record output, then exit 1 (matches real behaviour)
    error() {
        echo "$*" >> "$ERROR_CAPTURE_FILE"
        echo "Error: $*" >&2
        exit 1
    }

    # Default ssh_cmd stub: record args, return 0
    ssh_cmd() {
        echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
        return 0
    }

    export -f load_config start_ssh_multiplex info success warn error ssh_cmd
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# Helper: invoke cmd_run in a subshell so exit calls don't abort bats.
# All exported functions and variables are inherited.
# Returns the subshell exit code.
# ---------------------------------------------------------------------------
_run_cmd_run() {
    # Reset capture files for this invocation
    > "$SSH_CMD_CAPTURE_FILE"
    > "$WARN_CAPTURE_FILE"
    > "$ERROR_CAPTURE_FILE"

    (
        # Re-declare stubs inside the subshell
        load_config() {
            SSH_USER="deploy"
            SSH_HOST="example.com"
            SSH_PORT="22"
            REMOTE_PATH="/var/www/myapp"
        }
        start_ssh_multiplex() { :; }
        info()    { :; }
        success() { :; }
        warn() {
            echo "$*" >> "$WARN_CAPTURE_FILE"
            echo "⚠ $*" >&2
        }
        error() {
            echo "$*" >> "$ERROR_CAPTURE_FILE"
            echo "Error: $*" >&2
            exit 1
        }
        ssh_cmd() {
            echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
            return 0
        }

        source "$RUN_SH"
        cmd_run "$@"
    )
}

# ---------------------------------------------------------------------------
# Helper: invoke cmd_run with a custom ssh_cmd exit code
# ---------------------------------------------------------------------------
_run_cmd_run_with_ssh_exit() {
    local ssh_exit_code="$1"
    shift

    > "$SSH_CMD_CAPTURE_FILE"
    > "$WARN_CAPTURE_FILE"
    > "$ERROR_CAPTURE_FILE"

    (
        load_config() {
            SSH_USER="deploy"
            SSH_HOST="example.com"
            SSH_PORT="22"
            REMOTE_PATH="/var/www/myapp"
        }
        start_ssh_multiplex() { :; }
        info()    { :; }
        success() { :; }
        warn() {
            echo "$*" >> "$WARN_CAPTURE_FILE"
            echo "⚠ $*" >&2
        }
        error() {
            echo "$*" >> "$ERROR_CAPTURE_FILE"
            echo "Error: $*" >&2
            exit 1
        }
        ssh_cmd() {
            echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
            return "$ssh_exit_code"
        }

        source "$RUN_SH"
        cmd_run "$@"
    )
}

# ---------------------------------------------------------------------------
# Helper: invoke cmd_run with a custom ssh_cmd that simulates a remote
# command whose output includes a .env sourcing warning on stderr.
# ---------------------------------------------------------------------------
_run_cmd_run_with_env_warning() {
    shift 0  # no extra args needed

    > "$SSH_CMD_CAPTURE_FILE"
    > "$WARN_CAPTURE_FILE"
    > "$ERROR_CAPTURE_FILE"

    (
        load_config() {
            SSH_USER="deploy"
            SSH_HOST="example.com"
            SSH_PORT="22"
            REMOTE_PATH="/var/www/myapp"
        }
        start_ssh_multiplex() { :; }
        info()    { :; }
        success() { :; }
        warn() {
            echo "$*" >> "$WARN_CAPTURE_FILE"
            echo "⚠ $*" >&2
        }
        error() {
            echo "$*" >> "$ERROR_CAPTURE_FILE"
            echo "Error: $*" >&2
            exit 1
        }
        # Simulate the remote side: .env absent → warning on stderr, then run cmd
        ssh_cmd() {
            echo "$@" >> "$SSH_CMD_CAPTURE_FILE"
            # Emit the warning that the remote preamble would produce when .env is absent
            echo "⚠ shared/.env introuvable. Exécutez 'shipnode env' pour envoyer votre fichier d'environnement." >&2
            return 0
        }

        source "$RUN_SH"
        cmd_run "$@"
    )
}

# ===========================================================================
# Test 1: No argument → exit 1 + usage message on stderr
# Validates: Requirement 3.1
# ===========================================================================

# Feature: shipnode-run, unit: no argument exits 1
@test "Unit [3.1]: 'shipnode run' with no argument exits with code 1" {
    # Validates: Requirement 3.1
    run _run_cmd_run
    [ "$status" -eq 1 ]
}

# Feature: shipnode-run, unit: no argument prints usage on stderr
@test "Unit [3.1]: 'shipnode run' with no argument prints usage message on stderr" {
    # Validates: Requirement 3.1
    # The error() stub writes to ERROR_CAPTURE_FILE; we also check stderr via `run`
    run _run_cmd_run
    # error() is called with a usage string — check stderr contains "Usage"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"shipnode run"* ]]
}

# Feature: shipnode-run, unit: no argument usage message mentions shipnode run
@test "Unit [3.1]: usage message references 'shipnode run'" {
    # Validates: Requirement 3.1
    _run_cmd_run 2>"$TEST_DIR/stderr.txt" || true
    grep -qi "shipnode run" "$TEST_DIR/stderr.txt" \
        || grep -qi "shipnode run" "$ERROR_CAPTURE_FILE"
}

# ===========================================================================
# Test 2: --tty "top" → interactive mode, -t flag used
# Validates: Requirements 2.2, 2.3
# ===========================================================================

# Feature: shipnode-run, unit: --tty activates interactive mode
@test "Unit [2.2]: 'shipnode run --tty top' uses SSH -t flag" {
    # Validates: Requirements 2.2, 2.3
    _run_cmd_run --tty "top"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" == *" -t "* ]]
}

# Feature: shipnode-run, unit: --tty does not use -T flag
@test "Unit [2.2]: 'shipnode run --tty top' does NOT use SSH -T flag" {
    # Validates: Requirements 2.2, 2.3
    _run_cmd_run --tty "top"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" != *" -T "* ]]
}

# Feature: shipnode-run, unit: --tty exits 0 on success
@test "Unit [2.2]: 'shipnode run --tty top' exits 0 when ssh_cmd succeeds" {
    # Validates: Requirements 2.2, 2.3
    run _run_cmd_run --tty "top"
    [ "$status" -eq 0 ]
}

# ===========================================================================
# Test 3: "node -e 'console.log(1)'" → command transmitted intact, -T flag
# Validates: Requirements 1.2, 1.5
# ===========================================================================

# Feature: shipnode-run, unit: command with spaces transmitted intact
@test "Unit [1.5]: non-interactive command uses SSH -T flag" {
    # Validates: Requirement 1.5
    _run_cmd_run "node -e 'console.log(1)'"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" == *" -T "* ]]
}

# Feature: shipnode-run, unit: command with spaces does not use -t flag
@test "Unit [1.5]: non-interactive command does NOT use SSH -t flag" {
    # Validates: Requirement 1.5
    _run_cmd_run "node -e 'console.log(1)'"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" != *" -t "* ]]
}

# Feature: shipnode-run, unit: command string is transmitted intact
@test "Unit [1.2]: command string is transmitted intact to SSH" {
    # Validates: Requirement 1.2
    # The user command must appear verbatim inside the remote command string
    _run_cmd_run "node -e 'console.log(1)'"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" == *"node -e 'console.log(1)'"* ]]
}

# ===========================================================================
# Test 4: SSH failure (exit 255) → warn() output contains SSH_USER, SSH_HOST, SSH_PORT
# Validates: Requirement 3.2
# ===========================================================================

# Feature: shipnode-run, unit: SSH failure triggers warn with connection params
@test "Unit [3.2]: SSH exit 255 triggers warn containing SSH_USER" {
    # Validates: Requirement 3.2
    run _run_cmd_run_with_ssh_exit 255 "echo hello"
    local warn_output
    warn_output="$(cat "$WARN_CAPTURE_FILE" 2>/dev/null || true)"
    # Also check stderr captured by `run`
    [[ "$warn_output" == *"deploy"* ]] || [[ "$output" == *"deploy"* ]]
}

# Feature: shipnode-run, unit: SSH failure warn contains SSH_HOST
@test "Unit [3.2]: SSH exit 255 triggers warn containing SSH_HOST" {
    # Validates: Requirement 3.2
    run _run_cmd_run_with_ssh_exit 255 "echo hello"
    local warn_output
    warn_output="$(cat "$WARN_CAPTURE_FILE" 2>/dev/null || true)"
    [[ "$warn_output" == *"example.com"* ]] || [[ "$output" == *"example.com"* ]]
}

# Feature: shipnode-run, unit: SSH failure warn contains SSH_PORT
@test "Unit [3.2]: SSH exit 255 triggers warn containing SSH_PORT" {
    # Validates: Requirement 3.2
    run _run_cmd_run_with_ssh_exit 255 "echo hello"
    local warn_output
    warn_output="$(cat "$WARN_CAPTURE_FILE" 2>/dev/null || true)"
    [[ "$warn_output" == *"22"* ]] || [[ "$output" == *"22"* ]]
}

# Feature: shipnode-run, unit: SSH failure propagates exit code 255
@test "Unit [3.2]: SSH exit 255 is propagated as exit code 255" {
    # Validates: Requirement 3.2
    run _run_cmd_run_with_ssh_exit 255 "echo hello"
    [ "$status" -eq 255 ]
}

# ===========================================================================
# Test 5: .env absent on server → warning on stderr, execution continues
# Validates: Requirement 3.3
# ===========================================================================

# Feature: shipnode-run, unit: .env absent emits warning on stderr
@test "Unit [3.3]: .env absent on server emits warning on stderr" {
    # Validates: Requirement 3.3
    # The remote preamble emits a warning when .env is absent; execution must continue
    run _run_cmd_run_with_env_warning "echo hello"
    # The warning text should appear in stderr (captured by `run` as $output)
    [[ "$output" == *"shared/.env"* ]] || [[ "$output" == *"introuvable"* ]]
}

# Feature: shipnode-run, unit: .env absent does not abort execution
@test "Unit [3.3]: .env absent on server does not abort execution (exit 0)" {
    # Validates: Requirement 3.3
    # ssh_cmd returns 0 even after emitting the .env warning → cmd_run must exit 0
    run _run_cmd_run_with_env_warning "echo hello"
    [ "$status" -eq 0 ]
}

# Feature: shipnode-run, unit: .env preamble is always included in remote command
@test "Unit [3.3]: remote command always includes .env sourcing preamble" {
    # Validates: Requirement 3.3
    # The preamble must attempt to source shared/.env regardless of its presence
    _run_cmd_run "echo hello"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" == *"shared/.env"* ]]
}

# ===========================================================================
# Test 6: `shipnode run bash` → auto-detected as interactive, -t flag used
# Validates: Requirements 2.1, 2.3
# ===========================================================================

# Feature: shipnode-run, unit: bash auto-detected as interactive
@test "Unit [2.1]: 'shipnode run bash' auto-detects interactive mode (-t flag)" {
    # Validates: Requirements 2.1, 2.3
    _run_cmd_run "bash"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" == *" -t "* ]]
}

# Feature: shipnode-run, unit: bash does not use -T flag
@test "Unit [2.1]: 'shipnode run bash' does NOT use -T flag" {
    # Validates: Requirements 2.1, 2.3
    _run_cmd_run "bash"
    local invocation
    invocation="$(cat "$SSH_CMD_CAPTURE_FILE")"
    [[ "$invocation" != *" -T "* ]]
}

# Feature: shipnode-run, unit: bash exits 0 on success
@test "Unit [2.1]: 'shipnode run bash' exits 0 when ssh_cmd succeeds" {
    # Validates: Requirements 2.1, 2.3
    run _run_cmd_run "bash"
    [ "$status" -eq 0 ]
}

# Feature: shipnode-run, unit: all known shells auto-detected as interactive
@test "Unit [2.1]: all known shells (bash, sh, zsh, fish) use -t flag" {
    # Validates: Requirement 2.1
    local known_shells=("bash" "sh" "zsh" "fish")
    local failures=0

    for shell in "${known_shells[@]}"; do
        > "$SSH_CMD_CAPTURE_FILE"
        (
            load_config() {
                SSH_USER="deploy"; SSH_HOST="example.com"
                SSH_PORT="22"; REMOTE_PATH="/var/www/myapp"
            }
            start_ssh_multiplex() { :; }
            info() { :; }; success() { :; }
            warn() { echo "$*" >> "$WARN_CAPTURE_FILE"; }
            error() { echo "$*" >> "$ERROR_CAPTURE_FILE"; exit 1; }
            ssh_cmd() { echo "$@" >> "$SSH_CMD_CAPTURE_FILE"; return 0; }
            source "$RUN_SH"
            cmd_run "$shell"
        ) 2>/dev/null

        local inv
        inv="$(cat "$SSH_CMD_CAPTURE_FILE" 2>/dev/null || true)"
        if [[ "$inv" != *" -t "* ]]; then
            echo "FAIL: '$shell' did not use -t flag. Invocation: $inv" >&2
            failures=$((failures + 1))
        fi
        if [[ "$inv" == *" -T "* ]]; then
            echo "FAIL: '$shell' incorrectly used -T flag. Invocation: $inv" >&2
            failures=$((failures + 1))
        fi
    done

    [ "$failures" -eq 0 ]
}
