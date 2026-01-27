# INTERACTIVE PROMPT HELPERS
# ============================================================================

# Prompt with default value
prompt_with_default() {
    local prompt=$1
    local default=$2
    local varname=$3
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        printf -v "$varname" '%s' "${input:-$default}"
    else
        read -p "$prompt: " input
        printf -v "$varname" '%s' "$input"
    fi
}

# Prompt with validation loop
prompt_with_validation() {
    local prompt=$1
    local validator=$2
    local varname=$3
    local default=${4:-}
    
    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " input
            input="${input:-$default}"
        else
            read -p "$prompt: " input
        fi
        
        if [ -z "$input" ] && [ -z "$default" ]; then
            warn "This field is required"
            continue
        fi
        
        if $validator "$input"; then
            printf -v "$varname" '%s' "$input"
            break
        else
            warn "Invalid input, please try again"
        fi
    done
}

# =============================================================================
# GUM UI WRAPPERS (with fallback)
# ============================================================================

# Enhanced input with Gum (or fallback to classic)
# Provides beautiful input prompts with Gum when available and TTY present
# Args:
#   $1: Prompt text
#   $2: Default value (optional)
#   $3: Placeholder text (optional, defaults to $2)
# Returns:
#   User input or default value
# Notes:
#   - Auto-fallback to classic prompts if Gum unavailable or no TTY
#   - TTY check ensures compatibility with CI/CD environments
gum_input() {
    local prompt=$1
    local default=${2:-}
    local placeholder=${3:-$default}
    
    # Check if we have a TTY (interactive terminal)
    if [ "$USE_GUM" = true ] && [ -t 0 ]; then
        local value=""
        if [ -n "$default" ]; then
            value=$(gum input --placeholder "$placeholder" --prompt "$prompt: " --value "$default" 2>/dev/null || echo "$default")
        else
            value=$(gum input --placeholder "$placeholder" --prompt "$prompt: " 2>/dev/null || echo "")
        fi
        echo "$value"
    else
        # Fallback to classic bash
        local result
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " result
            echo "${result:-$default}"
        else
            read -p "$prompt: " result
            echo "$result"
        fi
    fi
}

# Enhanced selection with Gum (or fallback to classic)
# Provides arrow-key selection menu with Gum when available
# Args:
#   $1: Header text
#   $@: Options to choose from (remaining arguments)
# Returns:
#   Selected option, or first option if selection fails
# Notes:
#   - Auto-fallback to numbered menu if Gum unavailable or no TTY
#   - Returns first option as default on error
gum_choose() {
    local header=$1
    shift
    local options=("$@")
    
    # Check if we have a TTY (interactive terminal)
    if [ "$USE_GUM" = true ] && [ -t 0 ]; then
        gum choose "${options[@]}" --header "$header" --cursor "> " 2>/dev/null || echo "${options[0]}"
    else
        # Fallback to classic bash
        echo "$header"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        read -p "Choose: " choice
        
        # Return the selected option
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
        else
            echo "${options[0]}"
        fi
    fi
}

# Enhanced confirmation with Gum (or fallback to classic)
# Provides yes/no confirmation prompt with Gum when available
# Args:
#   $1: Confirmation message
#   $2: Default value (y or n, default: y)
# Returns:
#   Exit code 0 for yes, 1 for no
# Notes:
#   - Auto-fallback to classic y/n prompt if Gum unavailable or no TTY
#   - Uses existing prompt_yes_no function as fallback
gum_confirm() {
    local message=$1
    local default=${2:-y}
    
    # Check if we have a TTY (interactive terminal)
    if [ "$USE_GUM" = true ] && [ -t 0 ]; then
        if [ "$default" = "y" ]; then
            gum confirm "$message" 2>/dev/null && return 0 || return 1
        else
            gum confirm "$message" --default=false 2>/dev/null && return 0 || return 1
        fi
    else
        # Fallback to existing function
        prompt_yes_no "$message" "$default"
    fi
}

# Enhanced styling with Gum (or fallback to classic)
gum_style() {
    local text=$1
    shift
    local args=("$@")
    
    if [ "$USE_GUM" = true ]; then
        gum style "${args[@]}" "$text" 2>/dev/null || echo "$text"
    else
        # Fallback to classic echo
        echo "$text"
    fi
}

# Show informative message about Gum if not installed
show_gum_tip() {
    if [ "$USE_GUM" = false ]; then
        echo ""
        info "💡 Tip: Install gum for enhanced interactive experience"
        echo "   https://github.com/charmbracelet/gum"
        echo ""
    fi
}

# INITIALIZATION COMMANDS
