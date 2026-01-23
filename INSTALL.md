# ShipNode Installation Guide

## Quick Install (Recommended)

```bash
cd ~/Code/Labs/shipnode
./install.sh
```

The interactive installer will guide you through the setup process.

## Installation Options

### Option 1: Symlink to /usr/local/bin (Recommended)

Creates a system-wide symlink. Requires sudo.

```bash
./install.sh
# Choose option 1
```

After installation, `shipnode` will be available globally from any directory.

**Pros:**
- Works in all shells (bash, zsh, fish, etc.)
- No shell config modifications needed
- Clean and standard approach

**Cons:**
- Requires sudo access

### Option 2: Add to ~/.bashrc

Adds ShipNode to your PATH in bash configuration.

```bash
./install.sh
# Choose option 2
```

After installation, run:
```bash
source ~/.bashrc
```

**Pros:**
- No sudo required
- Easy to modify or remove

**Cons:**
- Only works in bash
- Requires sourcing config after install

### Option 3: Add to ~/.zshrc

Same as option 2, but for zsh users.

```bash
./install.sh
# Choose option 3
```

After installation, run:
```bash
source ~/.zshrc
```

### Option 4: Add to both bash and zsh

If you use both shells or are unsure which one you use.

```bash
./install.sh
# Choose option 4
```

### Option 5: Manual Setup

Skip automatic installation and set up manually.

```bash
./install.sh
# Choose option 5
```

The installer will show you the commands to run manually.

## Verification

After installation, verify ShipNode is available:

```bash
shipnode help
```

You should see the ShipNode help menu.

## Troubleshooting

### "command not found: shipnode"

**After symlink installation:**
- Check if /usr/local/bin is in your PATH:
  ```bash
  echo $PATH | grep /usr/local/bin
  ```
- If not, add it to your shell config:
  ```bash
  export PATH="/usr/local/bin:$PATH"
  ```

**After PATH installation:**
- Make sure you sourced your shell config:
  ```bash
  source ~/.bashrc  # or ~/.zshrc
  ```
- Or restart your terminal

### "Permission denied"

Make sure the script is executable:
```bash
chmod +x ~/Code/Labs/shipnode/install.sh
```

### "Already in ~/.bashrc" or "Already in ~/.zshrc"

The installer detected an existing ShipNode entry in your config. This is safe to ignore.

## Uninstallation

To remove ShipNode:

```bash
cd ~/Code/Labs/shipnode
./uninstall.sh
```

The uninstaller will:
1. Remove symlink from /usr/local/bin (if exists)
2. Remove PATH entries from shell configs
3. Optionally delete the entire ShipNode directory

## Next Steps

After installation:

1. **Read the documentation**
   ```bash
   cat ~/Code/Labs/shipnode/README.md
   ```

2. **Initialize a project**
   ```bash
   cd /path/to/your/project
   shipnode init
   ```

3. **Deploy**
   ```bash
   shipnode deploy
   ```

## Support

If you encounter issues:
1. Check the README: `~/Code/Labs/shipnode/README.md`
2. Verify file permissions: `ls -la ~/Code/Labs/shipnode/`
3. Test the script directly: `bash ~/Code/Labs/shipnode/shipnode help`
