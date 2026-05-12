#!/usr/bin/env bats
#
# Feature: shipnode-run — Integration smoke tests for wiring
#
# Validates: Requirements 4.5, 4.6
#
# These tests verify that the run command is correctly wired into the
# ShipNode entry point and dispatcher without requiring a real SSH connection.
#
# Checks:
#   1. `source "$LIB_DIR/commands/run.sh"` is present in the `shipnode` entry point
#   2. `run)` case is present in `lib/commands/main.sh`
#   3. `bash -n lib/commands/run.sh` exits 0 (syntax check)
#   4. `shellcheck lib/commands/run.sh` exits 0 (lint check)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PROJECT_ROOT
}

# ===========================================================================
# Wiring: shipnode entry point sources run.sh
# ===========================================================================

# Feature: shipnode-run, wiring: run.sh sourced in entry point
@test "Smoke [4.6]: shipnode entry point sources lib/commands/run.sh" {
    # Validates: Requirement 4.6
    # The entry point must contain the source line for run.sh so that
    # cmd_run is available when main() dispatches to it.
    grep -qF 'source "$LIB_DIR/commands/run.sh"' "$PROJECT_ROOT/shipnode"
}

# ===========================================================================
# Wiring: main.sh dispatcher has run) case
# ===========================================================================

# Feature: shipnode-run, wiring: run) case present in main.sh
@test "Smoke [4.5]: lib/commands/main.sh contains run) dispatch case" {
    # Validates: Requirement 4.5
    # The case statement in main() must have a run) branch so that
    # `shipnode run ...` is routed to cmd_run.
    grep -qE '^[[:space:]]*run\)' "$PROJECT_ROOT/lib/commands/main.sh"
}

# Feature: shipnode-run, wiring: run) case dispatches to cmd_run
@test "Smoke [4.5]: run) case in main.sh dispatches to cmd_run" {
    # Validates: Requirement 4.5
    # The run) branch must call cmd_run (not some other function).
    grep -A2 -E '^[[:space:]]*run\)' "$PROJECT_ROOT/lib/commands/main.sh" \
        | grep -q 'cmd_run'
}

# ===========================================================================
# Syntax check: bash -n
# ===========================================================================

# Feature: shipnode-run, syntax: run.sh passes bash -n
@test "Smoke: bash -n lib/commands/run.sh exits 0 (no syntax errors)" {
    # Validates: Requirements 4.5, 4.6
    # A syntax error in run.sh would prevent sourcing and break the entire
    # shipnode entry point.
    run bash -n "$PROJECT_ROOT/lib/commands/run.sh"
    [ "$status" -eq 0 ]
}

# ===========================================================================
# Lint check: shellcheck
# ===========================================================================

# Feature: shipnode-run, lint: run.sh passes shellcheck
@test "Smoke: shellcheck lib/commands/run.sh exits 0 (no lint errors)" {
    # Validates: Requirements 4.5, 4.6
    # shellcheck must be available; skip gracefully if not installed.
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck not installed"
    fi
    run shellcheck "$PROJECT_ROOT/lib/commands/run.sh"
    [ "$status" -eq 0 ]
}
