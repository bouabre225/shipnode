# Installation

Install ShipNode on your local machine to deploy apps to your server.

## Requirements

- **Local machine**: macOS, Linux, or WSL on Windows
- **Server**: Ubuntu/Debian VPS or dedicated server
- **SSH access**: Password or key-based authentication to your server

## Install (Recommended)

Download and run the self-extracting installer:

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh -o shipnode-installer.sh && bash shipnode-installer.sh
```

Or download manually:

```bash
wget https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh
chmod +x shipnode-installer.sh
./shipnode-installer.sh
```

The installer will:
- Extract ShipNode to `~/.shipnode`
- Add ShipNode to your PATH via `~/.bashrc` (and `~/.zshrc` if present)
- Verify the installation

## Install from Source

For development or if you want to work on ShipNode itself:

```bash
git clone https://github.com/devalade/shipnode.git
cd shipnode
./shipnode help
```

### Why Use the Modular Version?

The modular version (`./shipnode`) sources all modules from `lib/` dynamically:

- **Instant feedback**: Changes to modules take effect immediately
- **Easy debugging**: Test individual modules in isolation
- **Better collaboration**: Work on separate modules without conflicts
- **Clean architecture**: Each module has a single responsibility

## Verify Installation

After installation, verify ShipNode is available:

```bash
shipnode help
```

You should see the ShipNode help menu.

## Update ShipNode

To update to the latest version:

```bash
# Installed via installer
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh -o shipnode-installer.sh && bash shipnode-installer.sh

# From source
cd shipnode
git pull origin main
```

## Uninstall

To remove ShipNode:

1. **Remove installation directory:**
   ```bash
   rm -rf ~/.shipnode
   ```

2. **Remove from shell config:**
   Edit `~/.bashrc` or `~/.zshrc` and remove the ShipNode export lines.

## Next Steps

- [Quick Start](./quick-start.md) - Deploy your first app
- [First Deploy](./first-deploy.md) - Complete tutorial
