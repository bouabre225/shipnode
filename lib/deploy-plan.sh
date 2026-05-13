detect_frontend_build_dir() {
    if [ -d "build" ]; then
        echo "build"
    elif [ -d "public" ]; then
        echo "public"
    else
        echo "dist"
    fi
}

deploy_plan_load() {
    DEPLOY_SKIP_BUILD=false
    if [ "${1:-}" = "--skip-build" ]; then
        DEPLOY_SKIP_BUILD=true
    fi

    DEPLOY_PKG_MANAGER=$(detect_pkg_manager)
    DEPLOY_PKG_INSTALL_CMD=$(get_pkg_install_cmd "$DEPLOY_PKG_MANAGER")
    DEPLOY_PKG_RUN_BUILD_CMD=$(get_pkg_run_cmd "$DEPLOY_PKG_MANAGER" "build")
    DEPLOY_FRONTEND_BUILD_DIR=$(detect_frontend_build_dir)
    DEPLOY_ZERO_DOWNTIME="${ZERO_DOWNTIME:-true}"
    DEPLOY_RELEASE_PREVIEW="$(date +"%Y%m%d%H%M%S")"
    DEPLOY_RELEASE_PREVIEW_PATH="$REMOTE_PATH/releases/$DEPLOY_RELEASE_PREVIEW"
}

deploy_plan_apply_globals() {
    PKG_MANAGER="$DEPLOY_PKG_MANAGER"
    PKG_INSTALL_CMD="$DEPLOY_PKG_INSTALL_CMD"
    PKG_RUN_CMD="$DEPLOY_PKG_RUN_BUILD_CMD"
}
