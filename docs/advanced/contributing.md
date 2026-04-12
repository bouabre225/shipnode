# Contributing

Contributions welcome! This guide covers how to work on ShipNode.

## Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/devalade/shipnode.git
   cd shipnode
   ```

2. **Run from source:**
   ```bash
   ./shipnode help
   ```

3. **Make changes:**
   ```bash
   vim lib/commands/deploy.sh
   ```

4. **Test immediately:**
   ```bash
   ./shipnode deploy
   ```

No rebuild needed - changes take effect immediately.

## Project Structure

```
shipnode/
├── shipnode              # Main entry point
├── lib/                  # Bash modules
│   ├── core.sh          # Utilities, logging
│   ├── release.sh       # Deployment logic
│   ├── framework.sh     # Framework detection
│   ├── validation.sh    # Input validation
│   └── commands/        # Command implementations
├── templates/           # PM2/Caddy templates
└── build.sh            # Distribution builder
```

## Adding a Command

1. Create `lib/commands/mycommand.sh`:
   ```bash
   cmd_mycommand() {
       load_config
       info "Running my command..."
   }
   ```

2. Add to dispatcher in `lib/commands/main.sh`:
   ```bash
   case "${1:-}" in
       mycommand)
           cmd_mycommand "$@"
           ;;
   esac
   ```

3. Update help in `lib/commands/help.sh`

## Code Style

- Use `error()` for fatal errors
- Use `warn()` for non-fatal warnings
- Use `info()` for progress output
- Use `success()` for completion messages
- Use `set -e` for functions that should exit on error
- Use `{{VAR}}` syntax in templates

## Testing

Test individual modules:

```bash
source lib/core.sh
source lib/validation.sh
validate_port "3000" && echo "Valid"
```

Build and test installer:

```bash
./build.sh
bash dist/shipnode-installer.sh
```

## Commit Messages

Follow conventional commits:

```
feat: add new command
fix: resolve issue with health check
docs: update README
refactor: simplify deploy logic
```

## Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Reporting Issues

Include:
- ShipNode version (`shipnode --version`)
- OS and Node.js version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs

## Resources

- [Architecture](../advanced/architecture.md) - Module documentation
- [GitHub Issues](https://github.com/devalade/shipnode/issues)
