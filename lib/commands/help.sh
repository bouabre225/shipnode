cmd_help() {
    cat << EOF
ShipNode v$VERSION - Simple Node.js Deployment Tool

Usage: shipnode <command> [options]

Commands:
    init                        Create shipnode.conf (interactive wizard)
    init --template <name>      Create config from framework template
    init --list-templates       List available framework templates
    init --non-interactive      Create basic shipnode.conf without prompts
    init --print                Print config to stdout (no file created)
    setup                       First-time server setup (Node, PM2, Caddy, jq)
    deploy              Deploy the application
    deploy --skip-build Deploy without running build step
    deploy --dry-run    Preview deployment without executing
    
Global Options:
    --config <path>     Use custom config file (default: shipnode.conf)
    --profile <env>     Use profile config: shipnode.<env>.conf
    doctor              Run pre-flight diagnostic checks
    doctor --security   Run non-destructive security audit
    harden              Interactive server security hardening wizard
    eject               Eject PM2/Caddy templates for customization
    eject pm2           Eject only PM2 ecosystem config template
    eject caddy         Eject only Caddy config template
    config              Show resolved config values
    config validate     Validate config without deploying
    metrics             Show real-time PM2 resource metrics (backend)
    env                 Upload .env file to server
    status              Check application status
    logs                View application logs (backend only)
    restart             Restart application (backend only)
    stop                Stop application (backend only)
    unlock              Clear deployment lock (if stuck)
    rollback [N]        Rollback to previous release (or N steps back)
    releases            List all available releases
    migrate             Migrate existing deployment to release structure
    upgrade             Upgrade ShipNode to latest version
    ci github           Generate GitHub Actions workflow
    ci env-sync         Sync shipnode.conf and .env to GitHub secrets
    ci env-sync --all   Sync without prompting for .env confirmation
    help                Show this help message

User Management:
    user sync           Sync users from users.yml to server
    user list           List all provisioned users
    user remove <user>  Revoke access for a specific user
    mkpasswd            Generate password hash for users.yml

Configuration:
    Edit shipnode.conf to configure your deployment settings.
    Supports both backend (Node.js + PM2) and frontend (static files) apps.

Custom Templates:
    Run 'shipnode eject' to create editable PM2/Caddy config templates.
    Ejected templates are preserved across deploys.

    .shipnode/templates/ecosystem.config.cjs  - PM2 process config
    .shipnode/templates/Caddyfile.caddy        - Caddy web server config

    Template variables (auto-replaced on deploy):
      {{APP_NAME}}, {{INTERPRETER}}, {{REMOTE_PATH}}, {{BACKEND_PORT}}
      {{DOMAIN}}, {{SERVE_PATH}}

Deploy Excludes:
    Create .shipnodeignore to control which files are synced to the server.
    Uses the same syntax as .gitignore (one pattern per line).
    If .shipnodeignore is missing, built-in defaults are used.
    Run 'shipnode eject' to generate a starter .shipnodeignore.

Zero-Downtime Deployment:
    ZERO_DOWNTIME=true           Enable atomic deployments (default)
    KEEP_RELEASES=5              Number of releases to keep (default: 5)
    HEALTH_CHECK_ENABLED=true    Enable health checks (default: true)
    HEALTH_CHECK_PATH=/health    Health endpoint (default: /health)
    HEALTH_CHECK_TIMEOUT=30      Health check timeout seconds (default: 30)
    HEALTH_CHECK_RETRIES=3       Number of health check retries (default: 3)

User Provisioning:
    Create users.yml with user definitions, then run 'shipnode user sync'.
    Generate password hashes with 'shipnode mkpasswd'.

Templates:
    Use framework templates to skip auto-detection and get preset configurations:

    Backend:     express, nestjs, fastify, koa, hapi, hono, adonisjs
    Fullstack:   nextjs, nuxt, remix, astro
    Frontend:    react, vue, svelte, angular, solid, custom

Examples:
    shipnode init                      # Create config file
    shipnode init --template express   # Use Express.js template
    shipnode init --template nextjs    # Use Next.js template
    shipnode init --template react     # Use React template
    shipnode init --list-templates     # List all available templates
    shipnode init --print              # Print config to stdout
    shipnode init --print --template express  # Print Express template config
    shipnode setup                     # Setup server (first time)
    shipnode doctor                    # Run diagnostics
    shipnode doctor --security         # Run security audit
    shipnode harden                    # Interactive security hardening
    shipnode deploy                    # Deploy your app
    shipnode deploy --profile staging  # Deploy using shipnode.staging.conf
    shipnode deploy --config custom.conf  # Deploy using custom config file
    shipnode --profile prod deploy     # Alternative flag position
    shipnode env                       # Upload .env file to server
    shipnode unlock                    # Clear stuck deployment lock
    shipnode rollback                  # Rollback to previous release
    shipnode rollback 2                # Rollback 2 releases back
    shipnode releases                  # List all releases
    shipnode migrate                   # Migrate to release structure
    shipnode mkpasswd                  # Generate password hash
    shipnode ci github                 # Generate GitHub Actions workflow
    shipnode ci env-sync               # Sync shipnode.conf and .env to GitHub secrets
    shipnode ci env-sync --all         # Sync all without prompting
    shipnode eject                     # Eject PM2 + Caddy templates
    shipnode eject pm2                 # Eject only PM2 template
    shipnode eject caddy               # Eject only Caddy template
    shipnode config                    # Show resolved config
    shipnode metrics                   # Show PM2 resource metrics
    shipnode user sync                 # Provision users from users.yml
    shipnode user list                 # List provisioned users
    shipnode user remove alice         # Revoke access for alice

EOF
}

# Main command dispatcher
