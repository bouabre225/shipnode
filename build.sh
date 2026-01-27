#!/usr/bin/env bash
#
# ShipNode Build Script
# Bundles all modules into a single distributable file
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
OUTPUT_FILE="$SCRIPT_DIR/shipnode"

# Modules to include (in order of dependency)
MODULES=(
    "lib/core.sh"
    "lib/release.sh"
    "lib/database.sh"
    "lib/users.sh"
    "lib/framework.sh"
    "lib/validation.sh"
    "lib/prompts.sh"
    "lib/commands/config.sh"
    "lib/commands/users-yaml.sh"
    "lib/commands/user.sh"
    "lib/commands/mkpasswd.sh"
    "lib/commands/init.sh"
    "lib/commands/setup.sh"
    "lib/commands/deploy.sh"
    "lib/commands/status.sh"
    "lib/commands/unlock.sh"
    "lib/commands/rollback.sh"
    "lib/commands/migrate.sh"
    "lib/commands/env.sh"
    "lib/commands/help.sh"
    "lib/commands/main.sh"
)

echo "Building ShipNode..."
echo ""

# Create header
cat > "$OUTPUT_FILE" << 'HEADER'
#!/usr/bin/env bash
#
# ShipNode - Simple Node.js Deployment Tool
# Version: 1.1.0
#
# This file is auto-generated. Do not edit directly.
# Source: https://github.com/devalade/shipnode
#

set -e

HEADER

# Concatenate all modules
for module in "${MODULES[@]}"; do
    module_path="$SCRIPT_DIR/$module"
    if [ -f "$module_path" ]; then
        echo "  → Adding $(basename "$module")"
        # Add module header comment
        echo "" >> "$OUTPUT_FILE"
        echo "# ============================================================================" >> "$OUTPUT_FILE"
        echo "# MODULE: $(basename "$module")" >> "$OUTPUT_FILE"
        echo "# ============================================================================" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        # Append module content
        cat "$module_path" >> "$OUTPUT_FILE"
    else
        echo "  ✗ Warning: $module not found"
    fi
done

# Make executable
chmod +x "$OUTPUT_FILE"

echo ""
echo "✓ Build complete: $OUTPUT_FILE"
echo ""
echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo "Lines: $(wc -l < "$OUTPUT_FILE")"
