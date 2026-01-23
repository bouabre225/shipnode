#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ShipNode Installer v1.0.0      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SHIPNODE_BIN="$SCRIPT_DIR/shipnode"

# Check if shipnode exists
if [ ! -f "$SHIPNODE_BIN" ]; then
    echo -e "${RED}Error: shipnode binary not found at $SHIPNODE_BIN${NC}"
    exit 1
fi

# Make executable
chmod +x "$SHIPNODE_BIN"
echo -e "${GREEN}✓${NC} Made shipnode executable"

# Offer installation methods
echo
echo "Choose installation method:"
echo "  1) Symlink to /usr/local/bin (recommended, requires sudo)"
echo "  2) Add to PATH in ~/.bashrc"
echo "  3) Add to PATH in ~/.zshrc"
echo "  4) Both bashrc and zshrc"
echo "  5) Skip (manual setup)"
echo

read -p "Enter choice [1-5]: " -n 1 -r
echo

case $REPLY in
    1)
        echo -e "${BLUE}→${NC} Creating symlink to /usr/local/bin..."
        sudo ln -sf "$SHIPNODE_BIN" /usr/local/bin/shipnode
        echo -e "${GREEN}✓${NC} Symlink created"

        # Verify
        if command -v shipnode &> /dev/null; then
            echo -e "${GREEN}✓${NC} Installation successful!"
            echo -e "\nShipNode is now available globally."
        else
            echo -e "${YELLOW}⚠${NC} Symlink created but shipnode not in PATH. Check your PATH settings."
        fi
        ;;
    2)
        echo -e "${BLUE}→${NC} Adding to ~/.bashrc..."
        EXPORT_LINE="export PATH=\"$SCRIPT_DIR:\$PATH\""

        if grep -q "$SCRIPT_DIR" ~/.bashrc 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Already in ~/.bashrc"
        else
            echo "" >> ~/.bashrc
            echo "# ShipNode" >> ~/.bashrc
            echo "$EXPORT_LINE" >> ~/.bashrc
            echo -e "${GREEN}✓${NC} Added to ~/.bashrc"
        fi

        echo -e "\n${BLUE}Run:${NC} source ~/.bashrc"
        echo -e "or restart your terminal to use shipnode"
        ;;
    3)
        echo -e "${BLUE}→${NC} Adding to ~/.zshrc..."
        EXPORT_LINE="export PATH=\"$SCRIPT_DIR:\$PATH\""

        if grep -q "$SCRIPT_DIR" ~/.zshrc 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Already in ~/.zshrc"
        else
            echo "" >> ~/.zshrc
            echo "# ShipNode" >> ~/.zshrc
            echo "$EXPORT_LINE" >> ~/.zshrc
            echo -e "${GREEN}✓${NC} Added to ~/.zshrc"
        fi

        echo -e "\n${BLUE}Run:${NC} source ~/.zshrc"
        echo -e "or restart your terminal to use shipnode"
        ;;
    4)
        echo -e "${BLUE}→${NC} Adding to both ~/.bashrc and ~/.zshrc..."
        EXPORT_LINE="export PATH=\"$SCRIPT_DIR:\$PATH\""

        # Bashrc
        if grep -q "$SCRIPT_DIR" ~/.bashrc 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Already in ~/.bashrc"
        else
            echo "" >> ~/.bashrc
            echo "# ShipNode" >> ~/.bashrc
            echo "$EXPORT_LINE" >> ~/.bashrc
            echo -e "${GREEN}✓${NC} Added to ~/.bashrc"
        fi

        # Zshrc
        if grep -q "$SCRIPT_DIR" ~/.zshrc 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Already in ~/.zshrc"
        else
            echo "" >> ~/.zshrc
            echo "# ShipNode" >> ~/.zshrc
            echo "$EXPORT_LINE" >> ~/.zshrc
            echo -e "${GREEN}✓${NC} Added to ~/.zshrc"
        fi

        echo -e "\n${BLUE}Run:${NC} source ~/.bashrc (or ~/.zshrc)"
        echo -e "or restart your terminal to use shipnode"
        ;;
    5)
        echo -e "${YELLOW}⚠${NC} Skipping PATH setup"
        echo -e "\nManual setup options:"
        echo -e "  1. Symlink: ${BLUE}sudo ln -s $SHIPNODE_BIN /usr/local/bin/shipnode${NC}"
        echo -e "  2. PATH: Add ${BLUE}export PATH=\"$SCRIPT_DIR:\$PATH\"${NC} to your shell config"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete! 🎉      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
echo
echo "Quick start:"
echo -e "  ${BLUE}shipnode help${NC}       # View all commands"
echo -e "  ${BLUE}shipnode init${NC}       # Initialize a project"
echo -e "  ${BLUE}shipnode deploy${NC}     # Deploy your app"
echo
echo "Documentation: $SCRIPT_DIR/README.md"
echo
