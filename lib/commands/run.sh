#!/usr/bin/env bash
#
# lib/commands/run.sh — shipnode run
#
# Execute a one-off command on the production server in the application context:
#   - Working directory: $REMOTE_PATH/current/
#   - Environment:       $REMOTE_PATH/shared/.env (sourced, with warning if absent)
#
# Public entry point: cmd_run "$@"
#

# Known shells that trigger automatic interactive (TTY) mode
KNOWN_SHELLS="bash sh zsh fish"

# ---------------------------------------------------------------------------
# _run_parse_args "$@"
#
# Strips --tty from the argument list and populates:
#   _RUN_CMD         — the remote command string (all non-flag arguments joined)
#   _RUN_INTERACTIVE — "true" if --tty was present or command is a known shell,
#                      "false" otherwise
# ---------------------------------------------------------------------------
_run_parse_args() {
    _RUN_CMD=""
    _RUN_INTERACTIVE="false"

    local tty_flag=false
    local remaining=()

    for arg in "$@"; do
        if [ "$arg" = "--tty" ]; then
            tty_flag=true
        else
            remaining+=("$arg")
        fi
    done

    # Join all remaining arguments as the command (supports unquoted multi-word forms)
    if [ "${#remaining[@]}" -gt 0 ]; then
        _RUN_CMD="${remaining[*]}"
    fi

    # Determine interactive mode
    if [ "$tty_flag" = true ]; then
        _RUN_INTERACTIVE="true"
    elif [ -n "$_RUN_CMD" ] && _run_is_interactive "$_RUN_CMD"; then
        _RUN_INTERACTIVE="true"
    fi
}

# ---------------------------------------------------------------------------
# _run_is_interactive <cmd>
#
# Returns 0 (true) if the basename of <cmd> matches a known shell.
# Returns 1 (false) otherwise.
# ---------------------------------------------------------------------------
_run_is_interactive() {
    local cmd="$1"
    local base
    base="$(basename "$cmd")"

    for shell in $KNOWN_SHELLS; do
        if [ "$base" = "$shell" ]; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# _run_build_remote_cmd <cmd>
#
# Outputs the full remote command string:
#   cd "$REMOTE_PATH/current" &&
#   { [ -f "$REMOTE_PATH/shared/.env" ] && source "$REMOTE_PATH/shared/.env" ||
#     echo "Warning: ..." >&2; } &&
#   <cmd>
# ---------------------------------------------------------------------------
_run_build_remote_cmd() {
    local cmd="$1"
    printf '%s' \
        "cd \"$REMOTE_PATH/current\" && " \
        "{ [ -f \"$REMOTE_PATH/shared/.env\" ] && source \"$REMOTE_PATH/shared/.env\" || " \
        "echo \"Warning: shared/.env not found. Run 'shipnode env' to upload your environment file.\" >&2; } && " \
        "$cmd"
}

# ---------------------------------------------------------------------------
# _run_exec <interactive> <remote_cmd>
#
# Calls ssh_cmd with the correct TTY flag and propagates the exit code.
# Exit 255 triggers a connection-failure warning.
# Negative exit codes are normalised to 1.
# ---------------------------------------------------------------------------
_run_exec() {
    local interactive="$1"
    local remote_cmd="$2"
    local tty_flag="-T"

    if [ "$interactive" = "true" ]; then
        tty_flag="-t"
    fi

    ssh_cmd -p "$SSH_PORT" $tty_flag "$SSH_USER@$SSH_HOST" "$remote_cmd"
    local exit_code=$?

    # Warn on SSH connection failure (exit 255)
    if [ "$exit_code" -eq 255 ]; then
        warn "SSH connection failed (user=$SSH_USER host=$SSH_HOST port=$SSH_PORT). Try manually: ssh -p $SSH_PORT $SSH_USER@$SSH_HOST"
    fi

    exit $exit_code
}

# ---------------------------------------------------------------------------
# cmd_run "$@"
#
# Public entry point called by main.sh.
# ---------------------------------------------------------------------------
cmd_run() {
    load_config

    _run_parse_args "$@"

    # Guard: no command provided
    if [ -z "$_RUN_CMD" ]; then
        error "Usage: shipnode run [--tty] \"<command>\"\n  Example: shipnode run \"npm run migrate\"\n  Example: shipnode run bash"
    fi

    local remote_cmd
    remote_cmd="$(_run_build_remote_cmd "$_RUN_CMD")"

    _run_exec "$_RUN_INTERACTIVE" "$remote_cmd"
}
