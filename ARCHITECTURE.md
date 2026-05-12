# ShipNode Architecture

This document describes the internal architecture and module organization of ShipNode.

## Overview

ShipNode is organized as a modular bash project to improve maintainability, testability, and collaboration. The codebase is split into focused modules, each with a single responsibility.

**Total: ~8,484 lines** across 27 modules.

## Directory Structure

```
shipnode/
├── shipnode                    # Main entry point (50 lines)
├── lib/
│   ├── core.sh                # Core utilities, globals, template rendering (247 lines)
│   ├── pkg-manager.sh         # Package manager detection + PM2 template generation (236 lines)
│   ├── release.sh             # Release management with metadata tracking (263 lines)
│   ├── database.sh            # Database and Redis operations
│   ├── users.sh               # User provisioning helpers (352 lines)
│   ├── framework.sh           # Framework detection (259 lines)
│   ├── validation.sh          # Input validation (287 lines)
│   ├── prompts.sh             # Interactive prompts + Gum UI (178 lines)
│   ├── templates.sh           # Framework preset configurations (172 lines)
│   └── commands/              # Command implementations
│       ├── config.sh          # Configuration loading (110 lines)
│       ├── users-yaml.sh      # Users.yml generation (153 lines)
│       ├── user.sh            # User management commands (207 lines)
│       ├── mkpasswd.sh        # Password generation (36 lines)
│       ├── init.sh            # Initialize command (2007 lines)
│       ├── setup.sh           # Setup command (108 lines)
│       ├── deploy.sh          # Deploy command (819 lines)
│       ├── doctor.sh          # Diagnostics command (603 lines)
│       ├── status.sh          # Rich status dashboard (336 lines)
│       ├── unlock.sh          # Unlock command (40 lines)
│       ├── rollback.sh        # Rollback command (86 lines)
│       ├── migrate.sh         # Migrate command (92 lines)
│       ├── env.sh             # Environment upload (42 lines)
│       ├── run.sh             # Run command in app context (134 lines)
│       ├── eject.sh           # Eject PM2/Caddy templates (266 lines)
│       ├── metrics.sh         # PM2 resource monitoring (12 lines)
│       ├── config-cmd.sh      # Config show/validate/path (137 lines)
│       ├── upgrade.sh         # Upgrade command (104 lines)
│       ├── ci.sh              # CI/CD commands (362 lines)
│       ├── harden.sh          # Security hardening (476 lines)
│       ├── help.sh            # Help command (129 lines)
│       └── main.sh            # Main dispatcher (143 lines)
├── templates/                 # Ejectable template files
│   ├── ecosystem.config.cjs.tmpl  # PM2 config template
│   ├── Caddyfile.backend.tmpl      # Backend Caddy template
│   ├── Caddyfile.frontend.tmpl    # Frontend Caddy template
│   ├── pre-deploy.sh.template      # Pre-deploy hook template
│   ├── post-deploy.sh.template     # Post-deploy hook template
│   └── shipnodeignore.template     # .shipnodeignore template
├── build.sh                   # Build script for distribution (81 lines)
└── examples/                  # Example projects
```

## Module Dependencies

Modules are loaded in a specific order to ensure dependencies are available:

1. **core.sh** - No dependencies, provides globals, logging, template rendering
2. **pkg-manager.sh** - Depends on core.sh
3. **release.sh** - Depends on core.sh
4. **database.sh** - Depends on core.sh
5. **users.sh** - Depends on core.sh
6. **framework.sh** - Depends on core.sh
7. **validation.sh** - Depends on core.sh
8. **prompts.sh** - Depends on core.sh
9. **templates.sh** - Depends on core.sh
10. **commands/config.sh** - Depends on core.sh
11. **commands/users-yaml.sh** - Depends on core.sh, validation.sh
12. **commands/user.sh** - Depends on core.sh, users.sh, validation.sh
13. **commands/mkpasswd.sh** - Depends on core.sh
14. **commands/init.sh** - Depends on core.sh, framework.sh, validation.sh, prompts.sh
15. **commands/setup.sh** - Depends on core.sh, release.sh, database.sh
16. **commands/deploy.sh** - Depends on core.sh, release.sh, pkg-manager.sh
17. **commands/doctor.sh** - Depends on core.sh
18. **commands/status.sh** - Depends on core.sh
19. **commands/unlock.sh** - Depends on core.sh, release.sh
20. **commands/rollback.sh** - Depends on core.sh, release.sh
21. **commands/migrate.sh** - Depends on core.sh, release.sh
22. **commands/env.sh** - Depends on core.sh
23. **commands/run.sh** — Depends on core.sh
24. **commands/eject.sh** - Depends on core.sh
25. **commands/metrics.sh** - Depends on core.sh
26. **commands/config-cmd.sh** - Depends on core.sh
27. **commands/upgrade.sh** - Depends on core.sh
28. **commands/ci.sh** - Depends on core.sh
29. **commands/harden.sh** - Depends on core.sh
30. **commands/help.sh** - Depends on core.sh
31. **commands/main.sh** - Depends on all other modules

## Module Descriptions

### Core Modules

#### core.sh (247 lines)

**Purpose:** Global variables, colors, logging functions, OS detection, Gum installation, template rendering

**Key Functions:**
- `error()`, `success()`, `info()`, `warn()` - Logging functions
- `has_gum()` - Check if Gum is installed
- `detect_os()` - Detect OS and package manager
- `install_gum()` - Install Gum UI framework
- `render_template()` - Replace `{{VAR}}` placeholders in template files using sed
- `resolve_template()` - Find user template (ejected or project-root) before falling back to built-in

**Globals:**
- `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC` - Color codes
- `VERSION` - ShipNode version
- `USE_GUM` - Enhanced UI flag

#### release.sh (263 lines)

**Purpose:** Zero-downtime deployment release management with deployment metadata tracking

**Key Functions:**
- `generate_release_timestamp()` - Create unique release ID
- `get_release_path()` - Get path for a release
- `setup_release_structure()` - Create release directories
- `acquire_deploy_lock()` - Prevent concurrent deployments
- `release_deploy_lock()` - Release deployment lock
- `switch_symlink()` - Atomic symlink switching
- `perform_health_check()` - Validate deployment health with timing metrics
- `record_release()` - Track release history with duration, commit, health check data
- `get_previous_release()` - Find previous release
- `cleanup_old_releases()` - Remove old releases
- `rollback_to_release()` - Rollback to specific release

#### database.sh

**Purpose:** Database setup and management operations

**Key Functions:**
- `setup_databases()` - Dispatch configured database and Redis setup
- `setup_postgresql()` - Install and configure PostgreSQL
- `setup_mysql()` - Install and configure MySQL
- `setup_sqlite()` - Install SQLite and create database file
- `setup_redis()` - Install and configure Redis

#### users.sh (352 lines)

**Purpose:** User provisioning helper functions

**Key Functions:**
- `validate_username()` - Validate username format
- `validate_password_hash()` - Validate password hash
- `validate_ssh_key()` - Validate SSH key format
- `prompt_yes_no()` - Yes/no prompt with default
- `generate_password_hash()` - Create password hash
- `validate_email()` - Validate email format
- `read_key_file()` - Read SSH key from file

#### framework.sh (259 lines)

**Purpose:** Framework detection from package.json

**Key Functions:**
- `parse_package_json()` - Extract dependencies from package.json
- `suggest_app_type()` - Determine backend vs frontend
- `detect_framework()` - Identify framework from dependencies
- `suggest_port()` - Auto-detect port from scripts

**Supported Frameworks:**
- Backend: Express, NestJS, Fastify, Koa, Hono, AdonisJS
- Full-stack: Next.js, Nuxt, Remix, Astro
- Frontend: React, Vue, Svelte, SolidJS, Angular

#### validation.sh (287 lines)

**Purpose:** Input validation functions

**Key Functions:**
- `validate_ip_or_hostname()` - Validate IP or hostname
- `validate_port()` - Validate port number (1-65535)
- `validate_domain()` - Validate domain name
- `validate_pm2_app_name()` - Validate PM2 process name
- `test_ssh_connection()` - Test SSH connectivity
- `parse_users_yaml()` - Parse users.yml file

#### prompts.sh (178 lines)

**Purpose:** Interactive prompts with Gum UI support

**Key Functions:**
- `prompt_with_default()` - Prompt with default value
- `prompt_with_validation()` - Prompt with validation loop
- `gum_input()` - Enhanced input with Gum fallback
- `gum_choose()` - Enhanced selection with Gum fallback
- `gum_confirm()` - Enhanced confirmation with Gum fallback
- `gum_style()` - Enhanced styling with Gum fallback
- `show_gum_tip()` - Show Gum installation tip

#### templates.sh (172 lines)

**Purpose:** Framework preset configurations and template management

**Key Functions:**
- `load_template()` - Load framework preset templates
- `get_framework_config()` - Get preset configuration for framework

### Command Modules

#### commands/config.sh (110 lines)

**Purpose:** Configuration file loading

**Key Functions:**
- `load_config()` - Load and validate shipnode.conf

#### commands/users-yaml.sh (153 lines)

**Purpose:** Interactive users.yml generation

**Key Functions:**
- `init_users_yaml()` - Generate users.yml interactively

#### commands/user.sh (207 lines)

**Purpose:** User management commands

**Key Functions:**
- `cmd_user_sync()` - Sync users from users.yml to server
- `cmd_user_list()` - List provisioned users
- `cmd_user_remove()` - Remove user access

#### commands/mkpasswd.sh (36 lines)

**Purpose:** Password hash generation

**Key Functions:**
- `cmd_mkpasswd()` - Generate password hash for users.yml

#### commands/init.sh (2007 lines)

**Purpose:** Initialize project configuration (largest module)

**Key Functions:**
- `cmd_init()` - Main init command router
- `cmd_init_interactive()` - Interactive wizard
- `detect_framework()` - Detect project framework
- `generate_config()` - Generate shipnode.conf

#### commands/setup.sh (108 lines)

**Purpose:** First-time server setup

**Key Functions:**
- `cmd_setup()` - Setup server (Node, PM2, Caddy, jq)

#### commands/deploy.sh (819 lines)

**Purpose:** Deploy applications with template-aware PM2 and Caddy config generation

**Key Functions:**
- `cmd_deploy()` - Main deploy command
- `cmd_deploy_dry_run()` - Preview deployment without executing
- `deploy_backend()` - Deploy backend application
- `deploy_backend_zero_downtime()` - Zero-downtime backend deploy with duration/commit tracking
- `deploy_frontend()` - Deploy frontend application
- `deploy_frontend_zero_downtime()` - Zero-downtime frontend deploy
- `configure_caddy_backend()` - Configure Caddy for backend
- `configure_caddy_frontend()` - Configure Caddy for frontend

#### commands/status.sh (336 lines)

**Purpose:** Application status dashboard with rich output

**Key Functions:**
- `cmd_status()` - Check application status
- `cmd_status_backend()` - Rich PM2 dashboard: status, uptime, CPU, memory, releases, disk
- `cmd_status_frontend()` - Frontend status: file count, size, release, Caddy status
- `cmd_logs()` - View application logs
- `cmd_restart()` - Restart application
- `cmd_stop()` - Stop application

#### commands/unlock.sh (40 lines)

**Purpose:** Clear deployment lock

**Key Functions:**
- `cmd_unlock()` - Clear stuck deployment lock

#### commands/eject.sh (266 lines)

**Purpose:** Eject PM2/Caddy config templates for user customization

**Key Functions:**
- `cmd_eject()` - Eject templates (pm2, caddy, or all)
- `eject_pm2()` - Copy PM2 ecosystem template to `.shipnode/templates/`
- `eject_caddy()` - Copy Caddy template to `.shipnode/templates/`

#### commands/metrics.sh (12 lines)

**Purpose:** Real-time PM2 resource monitoring

**Key Functions:**
- `cmd_metrics()` - Open PM2 monit dashboard over SSH

#### commands/config-cmd.sh (137 lines)

**Purpose:** Config inspection and validation

**Key Functions:**
- `cmd_config()` - Route config subcommands (show, validate, path)
- `cmd_config_show()` - Display resolved config values
- `cmd_config_validate()` - Validate config file without deploying

#### commands/rollback.sh (86 lines)

**Purpose:** Rollback to previous releases

**Key Functions:**
- `cmd_rollback()` - Rollback to previous release
- `cmd_releases()` - List available releases

#### commands/migrate.sh (92 lines)

**Purpose:** Migrate existing deployments

**Key Functions:**
- `cmd_migrate()` - Migrate to release structure

#### commands/env.sh (42 lines)

**Purpose:** Environment variable management

**Key Functions:**
- `cmd_env()` - Upload .env file to server

#### commands/run.sh (134 lines)

**Purpose:** Execute a one-off command on the production server in the application context

**Key Functions:**
- `cmd_run()` - Main entry point; loads config, parses args, builds and executes remote command
- `_run_parse_args()` - Strips `--tty` from arguments and populates `CMD` and `INTERACTIVE`
- `_run_is_interactive()` - Returns true if the basename of the command matches a known shell (`bash`, `sh`, `zsh`, `fish`)
- `_run_build_remote_cmd()` - Constructs the full remote command string with context preamble (`cd $REMOTE_PATH/current` + `source $REMOTE_PATH/shared/.env`)
- `_run_exec()` - Calls `ssh_cmd` with the correct TTY flag (`-t` or `-T`) and propagates the exit code exactly

#### commands/ci.sh (362 lines)

**Purpose:** CI/CD integration commands

**Key Functions:**
- `cmd_ci()` - Route CI subcommands
- `cmd_ci_github()` - Generate GitHub Actions workflow
- `cmd_ci_env_sync()` - Sync secrets to GitHub

#### commands/harden.sh (476 lines)

**Purpose:** Server security hardening

**Key Functions:**
- `cmd_harden()` - Interactive security hardening wizard
- `harden_ssh()` - SSH hardening options
- `harden_firewall()` - UFW firewall setup
- `harden_fail2ban()` - Install and configure fail2ban

#### commands/doctor.sh (603 lines)

**Purpose:** Diagnostics and pre-flight checks

**Key Functions:**
- `cmd_doctor()` - Run diagnostic checks
- `check_ssh()` - Verify SSH connectivity
- `check_dependencies()` - Check server dependencies
- `check_disk_space()` - Verify sufficient disk space

#### commands/help.sh (129 lines)

**Purpose:** Display help information

**Key Functions:**
- `cmd_help()` - Show help message

#### commands/main.sh (143 lines)

**Purpose:** Main entry point and command dispatcher

**Key Functions:**
- `main()` - Parse arguments and dispatch to commands

#### commands/upgrade.sh (104 lines)

**Purpose:** Self-upgrade ShipNode

**Key Functions:**
- `cmd_upgrade()` - Upgrade ShipNode to latest version

## Template Files

Templates are located in `templates/` and used for ejection or direct deployment:

| File | Purpose |
|------|---------|
| `ecosystem.config.cjs.tmpl` | PM2 process manager configuration |
| `Caddyfile.backend.tmpl` | Caddy reverse proxy for backend apps |
| `Caddyfile.frontend.tmpl` | Caddy static file server for frontends |
| `pre-deploy.sh.template` | Pre-deploy hook script |
| `post-deploy.sh.template` | Post-deploy hook script |
| `shipnodeignore.template` | Default exclusions for rsync |

## Adding New Commands

To add a new command:

1. Create a new file in `lib/commands/`
2. Define a function `cmd_<command_name>()`
3. Add the case to `main()` in `commands/main.sh`
4. Update `commands/help.sh` with usage info
5. Update README.md with documentation

Example:

```bash
# lib/commands/mycommand.sh
cmd_mycommand() {
    load_config
    # Command implementation
}

# commands/main.sh
case "${1:-}" in
    mycommand)
        cmd_mycommand "$@"
        ;;
esac

# commands/help.sh
echo "    mycommand         Description of mycommand"
```

## Testing Individual Modules

Since modules are sourced independently, you can test them in isolation:

```bash
# Test validation module
source lib/core.sh
source lib/validation.sh

# Test functions
validate_port "3000" && echo "Valid port"
validate_port "70000" && echo "Invalid port"
```

## Building for Distribution

To create a single-file distribution:

```bash
./build.sh
```

This concatenates all modules into `shipnode-bundled` in the correct order.

## Best Practices

1. **Single Responsibility** - Each module should do one thing well
2. **Minimal Dependencies** - Keep module dependencies shallow
3. **No Side Effects** - Modules should only define functions, not execute code
4. **Consistent Naming** - Use `cmd_<name>()` for commands, descriptive names for helpers
5. **Documentation** - Add comments for complex functions
6. **Error Handling** - Use `error()` for fatal errors, `warn()` for warnings

## Future Improvements

Potential areas for modular expansion:

- **plugins/** - Plugin system for third-party extensions
- **hooks/** - Pre/post deploy hooks with chaining and local hooks
- **tests/** - Unit tests for individual modules
- **docs/** - Generated API documentation
- **Observability** - Deployment notification webhooks (Slack, email), uptime monitoring
- **Multi-app** - Deploy multiple apps from a single shipnode.conf
