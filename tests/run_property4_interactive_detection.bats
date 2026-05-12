#!/usr/bin/env bats
#
# Feature: shipnode-run, Property 4: interactive mode detection is correct
#
# **Validates: Requirements 2.1, 2.2, 4.1**
#
# Property 4: La détection du mode interactif est correcte
#
# For any remote command, interactive mode SHALL be activated if and only if:
#   - the command is a known shell (bash, sh, zsh, fish), OR
#   - the --tty flag is present in the arguments.
# For any other command without --tty, non-interactive mode SHALL be used.
#
# Test strategy:
#   - Source run.sh with mocked dependencies (load_config, ssh_cmd, error, warn)
#   - Call _run_parse_args to populate CMD and INTERACTIVE
#   - Assert INTERACTIVE value for each equivalence class
#   - Minimum 20 iterations covering all equivalence classes

# ---------------------------------------------------------------------------
# Setup: provide stubs for all external dependencies used by run.sh
# ---------------------------------------------------------------------------

setup() {
    # Project root is one level above the tests/ directory
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    RUN_SH="$PROJECT_ROOT/lib/commands/run.sh"

    # Stub load_config — sets required globals without reading a file
    load_config() {
        SSH_USER="testuser"
        SSH_HOST="testhost"
        SSH_PORT="22"
        REMOTE_PATH="/var/www/app"
    }

    # Stub ssh_cmd — captures arguments for inspection, returns 0
    SSH_CMD_ARGS=()
    ssh_cmd() {
        SSH_CMD_ARGS=("$@")
        return 0
    }

    # Stub error — records message, exits 1 (matches real behaviour)
    error() {
        ERROR_MSG="$1"
        exit 1
    }

    # Stub warn — records message, does not exit
    warn() {
        WARN_MSG="$1"
    }

    # Export stubs so subshells can see them
    export -f load_config ssh_cmd error warn

    # Source run.sh to load _run_parse_args and _run_is_interactive
    # run.sh must not execute anything on source (functions only)
    # shellcheck source=/dev/null
    source "$RUN_SH"
}

# ---------------------------------------------------------------------------
# Helper: call _run_parse_args and return the resulting INTERACTIVE value
# Usage: get_interactive_for [--tty] <cmd>
# ---------------------------------------------------------------------------
get_interactive_for() {
    # Reset state
    CMD=""
    INTERACTIVE="false"
    _run_parse_args "$@"
    echo "$INTERACTIVE"
}

# ===========================================================================
# Class 1 — Known shells without --tty → INTERACTIVE=true
# ===========================================================================

@test "Property 4 [1/20]: bash → INTERACTIVE=true" {
    result="$(get_interactive_for "bash")"
    [ "$result" = "true" ]
}

@test "Property 4 [2/20]: sh → INTERACTIVE=true" {
    result="$(get_interactive_for "sh")"
    [ "$result" = "true" ]
}

@test "Property 4 [3/20]: zsh → INTERACTIVE=true" {
    result="$(get_interactive_for "zsh")"
    [ "$result" = "true" ]
}

@test "Property 4 [4/20]: fish → INTERACTIVE=true" {
    result="$(get_interactive_for "fish")"
    [ "$result" = "true" ]
}

@test "Property 4 [5/20]: /bin/bash (absolute path) → INTERACTIVE=true" {
    result="$(get_interactive_for "/bin/bash")"
    [ "$result" = "true" ]
}

@test "Property 4 [6/20]: /usr/bin/zsh (absolute path) → INTERACTIVE=true" {
    result="$(get_interactive_for "/usr/bin/zsh")"
    [ "$result" = "true" ]
}

@test "Property 4 [7/20]: /usr/local/bin/fish (absolute path) → INTERACTIVE=true" {
    result="$(get_interactive_for "/usr/local/bin/fish")"
    [ "$result" = "true" ]
}

# ===========================================================================
# Class 2 — Non-shell commands without --tty → INTERACTIVE=false
# ===========================================================================

@test "Property 4 [8/20]: node → INTERACTIVE=false" {
    result="$(get_interactive_for "node")"
    [ "$result" = "false" ]
}

@test "Property 4 [9/20]: 'node -e console.log(1)' → INTERACTIVE=false" {
    result="$(get_interactive_for "node -e 'console.log(1)'")"
    [ "$result" = "false" ]
}

@test "Property 4 [10/20]: 'npm run migrate' → INTERACTIVE=false" {
    result="$(get_interactive_for "npm run migrate")"
    [ "$result" = "false" ]
}

@test "Property 4 [11/20]: top → INTERACTIVE=false" {
    result="$(get_interactive_for "top")"
    [ "$result" = "false" ]
}

@test "Property 4 [12/20]: htop → INTERACTIVE=false" {
    result="$(get_interactive_for "htop")"
    [ "$result" = "false" ]
}

@test "Property 4 [13/20]: 'ls -la' → INTERACTIVE=false" {
    result="$(get_interactive_for "ls -la")"
    [ "$result" = "false" ]
}

@test "Property 4 [14/20]: 'cat /etc/os-release' → INTERACTIVE=false" {
    result="$(get_interactive_for "cat /etc/os-release")"
    [ "$result" = "false" ]
}

@test "Property 4 [15/20]: python3 → INTERACTIVE=false (not a known shell)" {
    result="$(get_interactive_for "python3")"
    [ "$result" = "false" ]
}

# ===========================================================================
# Class 3 — Any command with --tty → INTERACTIVE=true
# ===========================================================================

@test "Property 4 [16/20]: --tty top → INTERACTIVE=true" {
    result="$(get_interactive_for --tty "top")"
    [ "$result" = "true" ]
}

@test "Property 4 [17/20]: --tty 'npm run dev' → INTERACTIVE=true" {
    result="$(get_interactive_for --tty "npm run dev")"
    [ "$result" = "true" ]
}

@test "Property 4 [18/20]: --tty python3 → INTERACTIVE=true" {
    result="$(get_interactive_for --tty "python3")"
    [ "$result" = "true" ]
}

@test "Property 4 [19/20]: --tty 'node server.js' → INTERACTIVE=true" {
    result="$(get_interactive_for --tty "node server.js")"
    [ "$result" = "true" ]
}

# ===========================================================================
# Class 4 — Known shell WITH --tty → INTERACTIVE=true (no double-activation)
# ===========================================================================

@test "Property 4 [20/20]: --tty bash → INTERACTIVE=true (no double-activation side effects)" {
    result="$(get_interactive_for --tty "bash")"
    [ "$result" = "true" ]
}

@test "Property 4 [bonus]: --tty zsh → INTERACTIVE=true (no double-activation side effects)" {
    result="$(get_interactive_for --tty "zsh")"
    [ "$result" = "true" ]
}

@test "Property 4 [bonus]: --tty fish → INTERACTIVE=true (no double-activation side effects)" {
    result="$(get_interactive_for --tty "fish")"
    [ "$result" = "true" ]
}

# ===========================================================================
# Invariant: --tty is stripped from CMD (not passed to remote command)
# ===========================================================================

@test "Property 4 [invariant]: --tty is stripped from CMD" {
    CMD=""
    INTERACTIVE="false"
    _run_parse_args --tty "top"
    # CMD must not contain --tty
    [[ "$CMD" != *"--tty"* ]]
}

@test "Property 4 [invariant]: CMD is preserved intact for non-shell command" {
    CMD=""
    INTERACTIVE="false"
    _run_parse_args "node -e 'process.exit(0)'"
    [ "$CMD" = "node -e 'process.exit(0)'" ]
}
