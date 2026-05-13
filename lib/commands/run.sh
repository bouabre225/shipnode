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
# _run_shell_quote <value>
#
# Quote a value for safe inclusion in a remote bash command.
# ---------------------------------------------------------------------------
_run_shell_quote() {
    local value="$1"
    printf '%q' "$value"
}

# ---------------------------------------------------------------------------
# _run_build_bin_repair_cmd
#
# Outputs a remote command that repairs execute bits only for binaries declared
# by installed packages. This avoids broad chmod over every file named bin/*.
# ---------------------------------------------------------------------------
_run_build_bin_repair_cmd() {
    printf '%s' \
        "if [ -d node_modules ]; then " \
        "find node_modules/.bin -mindepth 1 -maxdepth 1 \\( -type f -o -type l \\) -exec sh -c 'for bin do target=\$(readlink -f \"\$bin\" 2>/dev/null || printf \"%s\" \"\$bin\"); chmod +x \"\$target\" \"\$bin\" 2>/dev/null || true; done' sh {} + 2>/dev/null || true; " \
        "if command -v node >/dev/null 2>&1; then " \
        "node -e 'const fs=require(\"fs\"),path=require(\"path\");const root=\"node_modules\";function pkgs(){let out=[];for(const n of fs.readdirSync(root)){if(n===\".bin\")continue;const p=path.join(root,n);let s;try{s=fs.statSync(p)}catch{continue}if(!s.isDirectory())continue;if(n.startsWith(\"@\")){for(const c of fs.readdirSync(p)){const cp=path.join(p,c);try{if(fs.statSync(cp).isDirectory())out.push(cp)}catch{}}}else out.push(p)}return out}for(const p of pkgs()){let j;try{j=JSON.parse(fs.readFileSync(path.join(p,\"package.json\"),\"utf8\"))}catch{continue}const bins=typeof j.bin===\"string\"?[j.bin]:j.bin&&typeof j.bin===\"object\"?Object.values(j.bin):[];for(const b of bins){if(typeof b!==\"string\")continue;const f=path.resolve(p,b);if(!f.startsWith(path.resolve(root)+path.sep))continue;try{fs.chmodSync(f,0o755)}catch{}}}' 2>/dev/null || true; " \
        "fi; " \
        "fi"
}

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
#   export PATH=... &&
#   cd "$REMOTE_PATH/current" &&
#   source "$REMOTE_PATH/shared/.env" when present &&
#   repair package binary execute bits &&
#   mise exec "node@$NODE_VERSION" -- bash -lc <cmd>
# ---------------------------------------------------------------------------
_run_build_remote_cmd() {
    local cmd="$1"
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    local quoted_cmd
    quoted_cmd="$(_run_shell_quote "$cmd")"

    printf '%s' \
        "set -e; " \
        "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; " \
        "cd \"$REMOTE_PATH/current\" && " \
        "{ [ -f \"$REMOTE_PATH/shared/.env\" ] && source \"$REMOTE_PATH/shared/.env\" || " \
        "echo \"Warning: shared/.env not found. Run 'shipnode env' to upload your environment file.\" >&2; } && " \
        "$(_run_build_bin_repair_cmd); " \
        "MISE_BIN=\"\$(command -v mise 2>/dev/null || true)\"; " \
        "[ -z \"\$MISE_BIN\" ] && [ -x \"\$HOME/.local/bin/mise\" ] && MISE_BIN=\"\$HOME/.local/bin/mise\"; " \
        "if [ -n \"\$MISE_BIN\" ]; then " \
        "\"\$MISE_BIN\" install -y \"node@$node_version\" >/dev/null; " \
        "\"\$MISE_BIN\" use -g -y \"node@$node_version\" >/dev/null; " \
        "\"\$MISE_BIN\" exec \"node@$node_version\" -- bash -lc $quoted_cmd; " \
        "else " \
        "bash -lc $quoted_cmd; " \
        "fi"
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
        error "Usage: shipnode run [--tty] \"<command>\" [--config <file>|--profile <name>]\n  Example: shipnode run \"npm run migrate\"\n  Example: shipnode run bash\n  Example: shipnode run \"node -v\" --profile staging"
    fi

    local remote_cmd
    remote_cmd="$(_run_build_remote_cmd "$_RUN_CMD")"

    _run_exec "$_RUN_INTERACTIVE" "$remote_cmd"
}
