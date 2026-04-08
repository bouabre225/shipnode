# ShipNode Architecture

This document describes the internal architecture and module organization of ShipNode.

## Overview

ShipNode is organized as a modular bash project to improve maintainability, testability, and collaboration. The codebase is split into 21 focused modules, each with a single responsibility.

## Directory Structure

```
shipnode/
├── shipnode                    # Main entry point (sources all modules)
├── lib/
│   ├── core.sh                # Core utilities, globals, template rendering
│   ├── pkg-manager.sh         # Package manager detection + PM2 template generation
│   ├── release.sh             # Release management with metadata tracking
│   ├── database.sh            # Database operations
│   ├── users.sh               # User provisioning helpers
│   ├── framework.sh           # Framework detection
│   ├── validation.sh          # Input validation
│   ├── prompts.sh             # Interactive prompts + Gum UI
│   ├── templates.sh           # Framework preset configurations
│   └── commands/              # Command implementations
│       ├── config.sh          # Configuration loading
│       ├── users-yaml.sh      # Users.yml generation
│       ├── user.sh            # User management commands
│       ├── mkpasswd.sh        # Password generation
│       ├── init.sh            # Initialize command
│       ├── setup.sh           # Setup command
│       ├── deploy.sh          # Deploy command (template-aware)
│       ├── doctor.sh          # Diagnostics command
│       ├── status.sh          # Rich status dashboard
│       ├── unlock.sh          # Unlock command
│       ├── rollback.sh        # Rollback command
│       ├── migrate.sh         # Migrate command
│       ├── env.sh             # Environment upload
│       ├── eject.sh           # Eject PM2/Caddy templates
│       ├── metrics.sh         # PM2 resource monitoring
│       ├── config-cmd.sh      # Config show/validate/path
│       ├── upgrade.sh         # Upgrade command
│       ├── ci.sh              # CI/CD commands
│       ├── harden.sh          # Security hardening
│       ├── help.sh            # Help command
│       └── main.sh            # Main dispatcher
├── templates/                 # Ejectable template files
│   ├── ecosystem.config.cjs.tmpl  # PM2 config template
│   ├── Caddyfile.backend.tmpl     # Backend Caddy template
│   ├── Caddyfile.frontend.tmpl    # Frontend Caddy template
│   ├── pre-deploy.sh.template     # Pre-deploy hook template
│   └── post-deploy.sh.template    # Post-deploy hook template
├── build.sh                   # Build script for distribution
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
23. **commands/eject.sh** - Depends on core.sh
24. **commands/metrics.sh** - Depends on core.sh
25. **commands/config-cmd.sh** - Depends on core.sh
26. **commands/upgrade.sh** - Depends on core.sh
27. **commands/ci.sh** - Depends on core.sh
28. **commands/harden.sh** - Depends on core.sh
29. **commands/help.sh** - Depends on core.sh
30. **commands/main.sh** - Depends on all other modules

## Module Descriptions

### Core Modules

#### core.sh (240 lines)
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

#### release.sh (180 lines)
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

#### database.sh (70 lines)
**Purpose:** PostgreSQL setup and management

**Key Functions:**
- `setup_postgresql()` - Install and configure PostgreSQL

#### users.sh (78 lines)
**Purpose:** User provisioning helper functions

**Key Functions:**
- `validate_username()` - Validate username format
- `validate_password_hash()` - Validate password hash
- `validate_ssh_key()` - Validate SSH key format
- `prompt_yes_no()` - Yes/no prompt with default
- `generate_password_hash()` - Create password hash
- `validate_email()` - Validate email format
- `read_key_file()` - Read SSH key from file

#### framework.sh (219 lines)
**Purpose:** Framework detection from package.json

**Key Functions:**
- `parse_package_json()` - Extract dependencies from package.json
- `suggest_app_type()` - Determine backend vs frontend
- `detect_framework()` - Identify framework from dependencies
- `suggest_port()` - Auto-detect port from scripts

**Supported Frameworks:**
- Backend: Express, NestJS, Fastify, Koa, Hapi, Hono, AdonisJS
- Full-stack: Next.js, Nuxt, Remix, Astro
- Frontend: React, React Router, TanStack Router, Vue, Svelte, SolidJS, Angular

#### validation.sh (124 lines)
**Purpose:** Input validation functions

**Key Functions:**
- `validate_ip_or_hostname()` - Validate IP or hostname
- `validate_port()` - Validate port number (1-65535)
- `validate_domain()` - Validate domain name
- `validate_pm2_app_name()` - Validate PM2 process name
- `test_ssh_connection()` - Test SSH connectivity
- `parse_users_yaml()` - Parse users.yml file
- `create_remote_user()` - Create user on remote server
- `setup_user_ssh_dir()` - Setup SSH directory for user
- `add_user_ssh_key()` - Add SSH key to user
- `grant_deploy_permissions()` - Grant deployment permissions
- `grant_sudo_access()` - Grant sudo access
- `revoke_user_access()` - Revoke user access

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

### Command Modules

#### commands/config.sh (55 lines)
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

#### commands/init.sh (479 lines)
**Purpose:** Initialize project configuration

**Key Functions:**
- `cmd_init_legacy()` - Legacy non-interactive init
- `cmd_init_interactive()` - Interactive wizard
- `cmd_init()` - Router function

#### commands/setup.sh (79 lines)
**Purpose:** First-time server setup

**Key Functions:**
- `cmd_setup()` - Setup server (Node, PM2, Caddy, jq)

#### commands/deploy.sh (500 lines)
**Purpose:** Deploy applications with template-aware PM2 and Caddy config generation

**Key Functions:**
- `cmd_deploy()` - Main deploy command
- `cmd_deploy_dry_run()` - Preview deployment without executing
- `deploy_backend()` - Deploy backend application
- `deploy_backend_legacy()` - Legacy backend deploy
- `deploy_backend_zero_downtime()` - Zero-downtime backend deploy with duration/commit tracking
- `deploy_frontend()` - Deploy frontend application
- `deploy_frontend_legacy()` - Legacy frontend deploy
- `deploy_frontend_zero_downtime()` - Zero-downtime frontend deploy
- `configure_caddy_backend()` - Configure Caddy for backend (checks for ejected templates)
- `configure_caddy_frontend()` - Configure Caddy for frontend (checks for ejected templates)

#### commands/status.sh (200 lines)
**Purpose:** Application status dashboard with rich output for backend and frontend

**Key Functions:**
- `cmd_status()` - Check application status (routes to backend/frontend)
- `cmd_status_backend()` - Rich PM2 dashboard: status, uptime, CPU, memory, releases, disk
- `cmd_status_frontend()` - Frontend status: file count, size, release, Caddy status
- `cmd_logs()` - View application logs (backend only)
- `cmd_restart()` - Restart application
- `cmd_stop()` - Stop application

#### commands/unlock.sh (40 lines)
**Purpose:** Clear deployment lock

**Key Functions:**
- `cmd_unlock()` - Clear stuck deployment lock

#### commands/eject.sh (150 lines)
**Purpose:** Eject PM2/Caddy config templates for user customization

**Key Functions:**
- `cmd_eject()` - Eject templates (pm2, caddy, or all)
- `eject_pm2()` - Copy PM2 ecosystem template to `.shipnode/templates/`
- `eject_caddy()` - Copy Caddy template to `.shipnode/templates/` (backend or frontend)

#### commands/metrics.sh (15 lines)
**Purpose:** Real-time PM2 resource monitoring

**Key Functions:**
- `cmd_metrics()` - Open PM2 monit dashboard over SSH

#### commands/config-cmd.sh (100 lines)
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

#### commands/migrate.sh (84 lines)
**Purpose:** Migrate existing deployments

**Key Functions:**
- `cmd_migrate()` - Migrate to release structure

#### commands/env.sh (39 lines)
**Purpose:** Environment variable management

**Key Functions:**
- `cmd_env()` - Upload .env file to server

#### commands/help.sh (64 lines)
**Purpose:** Display help information

**Key Functions:**
- `cmd_help()` - Show help message

#### commands/main.sh (70 lines)
**Purpose:** Main entry point and command dispatcher

**Key Functions:**
- `main()` - Parse arguments and dispatch to commands

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
