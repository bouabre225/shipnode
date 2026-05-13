check_results_reset() {
    CHECK_HAS_ERRORS=false
    CHECK_HAS_WARNINGS=false
    CHECK_HAS_INFO=false
}

run_check() {
    local severity="$1"
    local check_fn="$2"

    if "$check_fn"; then
        return 0
    fi

    case "$severity" in
        error) CHECK_HAS_ERRORS=true ;;
        warning) CHECK_HAS_WARNINGS=true ;;
        info) CHECK_HAS_INFO=true ;;
    esac

    return 1
}

check_results_failed() {
    [ "${CHECK_HAS_ERRORS:-false}" = true ]
}

check_results_warned() {
    [ "${CHECK_HAS_WARNINGS:-false}" = true ]
}

check_results_informed() {
    [ "${CHECK_HAS_INFO:-false}" = true ]
}
