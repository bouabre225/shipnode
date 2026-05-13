main() {
    # Parse global --config and --profile flags
    # These can appear before or after the command
    local args=()
    local i=1
    local total=$#
    local cmd=""
    local cmd_args=()

    while [ $i -le $total ]; do
        local arg="${!i}"
        case "$arg" in
            --config)
                i=$((i + 1))
                if [ $i -le $total ]; then
                    SHIPNODE_CONFIG_FILE="${!i}"
                else
                    error "--config requires a path argument"
                fi
                ;;
            --profile)
                i=$((i + 1))
                if [ $i -le $total ]; then
                    SHIPNODE_CONFIG_FILE="shipnode.${!i}.conf"
                else
                    error "--profile requires an environment name (e.g., staging, prod)"
                fi
                ;;
            *)
                # First non-flag arg is the command
                if [ -z "$cmd" ]; then
                    cmd="$arg"
                else
                    cmd_args+=("$arg")
                fi
                ;;
        esac
        i=$((i + 1))
    done

    # Route to appropriate command
    case "${cmd:-}" in
        init)
            cmd_init "${cmd_args[@]}"
            ;;
        setup)
            cmd_setup
            ;;
        deploy)
            # Check for --dry-run flag
            local DRY_RUN=false
            local DEPLOY_ARGS=()
            for arg in "${cmd_args[@]}"; do
                if [ "$arg" = "--dry-run" ]; then
                    DRY_RUN=true
                else
                    DEPLOY_ARGS+=("$arg")
                fi
            done
            if [ "$DRY_RUN" = true ]; then
                cmd_deploy_dry_run "${DEPLOY_ARGS[@]}"
            else
                cmd_deploy "${DEPLOY_ARGS[@]}"
            fi
            ;;
        doctor)
            cmd_doctor "${cmd_args[@]}"
            ;;
        env)
            cmd_env
            ;;
        backup)
            cmd_backup "${cmd_args[@]}"
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs
            ;;
        restart)
            cmd_restart
            ;;
        stop)
            cmd_stop
            ;;
        unlock)
            cmd_unlock
            ;;
        rollback)
            cmd_rollback "${cmd_args[@]}"
            ;;
        releases)
            cmd_releases
            ;;
        migrate)
            cmd_migrate
            ;;
        user)
            case "${cmd_args[0]:-}" in
                sync)
                    cmd_user_sync
                    ;;
                list)
                    cmd_user_list
                    ;;
                remove)
                    cmd_user_remove "${cmd_args[1]}"
                    ;;
                *)
                    error "Unknown user command: ${cmd_args[0]:-}\nAvailable: sync, list, remove"
                    ;;
            esac
            ;;
        mkpasswd)
            cmd_mkpasswd
            ;;
        upgrade)
            cmd_upgrade
            ;;
        ci)
            cmd_ci "${cmd_args[@]}"
            ;;
        harden)
            cmd_harden
            ;;
        cloudflare)
            cmd_cloudflare "${cmd_args[@]}"
            ;;
        eject)
            cmd_eject "${cmd_args[0]:-all}"
            ;;
        metrics)
            cmd_metrics
            ;;
        config)
            cmd_config "${cmd_args[@]}"
            ;;
        run)
            cmd_run "${cmd_args[@]}"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        "")
            cmd_help
            ;;
        *)
            error "Unknown command: $cmd\nRun 'shipnode help' for usage."
            ;;
    esac
}
