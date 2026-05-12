#!/usr/bin/env bats
#
# Feature: shipnode-run — Unit test for main.sh dispatch integration
#
# Validates: Requirement 4.5
#
# Verifies that calling `main run "echo hello"` dispatches to `cmd_run`.
# cmd_run is mocked; the test asserts it is called with the expected arguments.

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve project root relative to this test file
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    MAIN_SH="$PROJECT_ROOT/lib/commands/main.sh"

    # Temporary directory for mock artifacts
    TEST_TMP="$(mktemp -d)"

    # File that records whether cmd_run was called and with what arguments
    CMD_RUN_CALL_FILE="$TEST_TMP/cmd_run_calls.txt"
    export CMD_RUN_CALL_FILE TEST_TMP PROJECT_ROOT MAIN_SH
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# Helper: invoke main() in a subshell with cmd_run mocked.
#
# All other cmd_* functions are stubbed to no-ops so that main.sh can be
# sourced without pulling in the full shipnode dependency tree.
# ---------------------------------------------------------------------------
_invoke_main_with_mock_cmd_run() {
    (
        # Stub every cmd_* that main.sh may reference so sourcing it is safe
        cmd_init()         { :; }
        cmd_setup()        { :; }
        cmd_deploy()       { :; }
        cmd_deploy_dry_run() { :; }
        cmd_doctor()       { :; }
        cmd_env()          { :; }
        cmd_backup()       { :; }
        cmd_status()       { :; }
        cmd_logs()         { :; }
        cmd_restart()      { :; }
        cmd_stop()         { :; }
        cmd_unlock()       { :; }
        cmd_rollback()     { :; }
        cmd_releases()     { :; }
        cmd_migrate()      { :; }
        cmd_user_sync()    { :; }
        cmd_user_list()    { :; }
        cmd_user_remove()  { :; }
        cmd_mkpasswd()     { :; }
        cmd_upgrade()      { :; }
        cmd_ci()           { :; }
        cmd_harden()       { :; }
        cmd_eject()        { :; }
        cmd_metrics()      { :; }
        cmd_config()       { :; }
        cmd_help()         { :; }
        error()            { echo "ERROR: $*" >&2; exit 1; }

        # Mock cmd_run: record the call and its arguments
        cmd_run() {
            echo "cmd_run called with: $*" >> "$CMD_RUN_CALL_FILE"
        }

        # Source the dispatcher under test
        # shellcheck source=/dev/null
        source "$MAIN_SH"

        # Invoke main with the provided arguments
        main "$@"
    )
}

# ===========================================================================
# Dispatch tests — Requirement 4.5
# ===========================================================================

# Feature: shipnode-run, dispatch: main run dispatches to cmd_run
@test "Dispatch [4.5]: 'main run \"echo hello\"' calls cmd_run" {
    # Validates: Requirement 4.5
    # The run) case in main() must route to cmd_run.
    > "$CMD_RUN_CALL_FILE"
    run _invoke_main_with_mock_cmd_run run "echo hello"
    [ "$status" -eq 0 ]
    [ -s "$CMD_RUN_CALL_FILE" ]
}

# Feature: shipnode-run, dispatch: cmd_run receives the command argument
@test "Dispatch [4.5]: 'main run \"echo hello\"' passes 'echo hello' to cmd_run" {
    # Validates: Requirement 4.5
    # cmd_run must receive the arguments that follow "run" on the command line.
    > "$CMD_RUN_CALL_FILE"
    _invoke_main_with_mock_cmd_run run "echo hello"
    grep -q "echo hello" "$CMD_RUN_CALL_FILE"
}

# Feature: shipnode-run, dispatch: cmd_run is not called for other commands
@test "Dispatch [4.5]: 'main help' does NOT call cmd_run" {
    # Validates: Requirement 4.5 (negative case — dispatch is exclusive)
    > "$CMD_RUN_CALL_FILE"
    _invoke_main_with_mock_cmd_run help
    [ ! -s "$CMD_RUN_CALL_FILE" ]
}

# Feature: shipnode-run, dispatch: cmd_run receives multiple arguments
@test "Dispatch [4.5]: 'main run --tty bash' passes '--tty bash' to cmd_run" {
    # Validates: Requirement 4.5
    # Flags and additional arguments after "run" must be forwarded intact.
    > "$CMD_RUN_CALL_FILE"
    _invoke_main_with_mock_cmd_run run --tty bash
    grep -q "\-\-tty" "$CMD_RUN_CALL_FILE"
    grep -q "bash" "$CMD_RUN_CALL_FILE"
}
