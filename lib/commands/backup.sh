cmd_backup() {
    local subcmd="${1:-run}"

    load_config

    case "$subcmd" in
        setup)
            setup_database_backups
            ;;
        run)
            run_database_backup
            ;;
        status)
            show_database_backup_status
            ;;
        list)
            list_database_backups
            ;;
        *)
            error "Unknown backup command: '$subcmd'\nAvailable: setup, run, status, list"
            ;;
    esac
}
