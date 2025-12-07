#!/usr/bin/env bash
#
# vhdm installer script
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/rjdinis/vhdm/go/scripts/install.sh | bash
#
# Options:
#   INSTALL_DIR  - Installation directory (default: /usr/local/bin)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if running in WSL
check_wsl() {
    if [[ ! -f /proc/version ]] || ! grep -qi microsoft /proc/version; then
        log_warn "This tool is designed for WSL2. Some features may not work outside WSL."
    fi
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    for cmd in qemu-img jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing optional dependencies: ${missing[*]}"
        log_info "Install with your package manager:"
        log_info "  # Arch Linux: sudo pacman -S qemu jq"
        log_info "  # Ubuntu/Debian: sudo apt install qemu-utils jq"
        echo ""
    fi
}

# Determine install directory
get_install_dir() {
    if [[ -n "${INSTALL_DIR:-}" ]]; then
        echo "$INSTALL_DIR"
    else
        echo "/usr/local/bin"
    fi
}

# Install from source
install_from_source() {
    local install_dir="$1"
    local tmp_dir
    
    log_info "Installing vhdm from source..."
    
    # Check for Go
    if ! command -v go &>/dev/null; then
        log_error "Go is required to build from source."
        log_info "Install Go: https://go.dev/dl/"
        exit 1
    fi
    
    # Create temp directory
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Clone repository
    log_info "Cloning repository..."
    if ! git clone --depth 1 --branch go https://github.com/rjdinis/vhdm.git "$tmp_dir/vhdm" 2>/dev/null; then
        log_error "Failed to clone repository"
        exit 1
    fi
    
    cd "$tmp_dir/vhdm"
    
    # Build
    log_info "Building vhdm..."
    VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    go build -ldflags "-s -w -X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE" \
        -o vhdm ./cmd/vhdm
    
    # Install binary
    log_info "Installing to $install_dir..."
    if [[ -w "$install_dir" ]]; then
        install -m 755 vhdm "$install_dir/vhdm"
    else
        sudo install -m 755 vhdm "$install_dir/vhdm"
    fi
    
    log_success "vhdm installed to $install_dir/vhdm"
}

# Setup shell completions
setup_completions() {
    local vhdm="$1/vhdm"
    local shell
    shell=$(basename "$SHELL")
    
    log_info "Setting up $shell completions..."
    
    case "$shell" in
        bash)
            if [[ -d /etc/bash_completion.d ]] && sudo test -w /etc/bash_completion.d 2>/dev/null; then
                "$vhdm" completion bash | sudo tee /etc/bash_completion.d/vhdm >/dev/null
                log_success "Bash completions installed to /etc/bash_completion.d/vhdm"
            else
                log_info "To enable completions, add to ~/.bashrc:"
                echo "    source <(vhdm completion bash)"
                echo ""
                log_info "Or install permanently with:"
                echo "    sudo mkdir -p /etc/bash_completion.d"
                echo "    vhdm completion bash | sudo tee /etc/bash_completion.d/vhdm >/dev/null"
            fi
            ;;
        zsh)
            log_info "To enable completions, add to ~/.zshrc:"
            echo "    source <(vhdm completion zsh)"
            echo ""
            log_info "Or install permanently with:"
            echo "    sudo mkdir -p /usr/local/share/zsh/site-functions"
            echo "    vhdm completion zsh | sudo tee /usr/local/share/zsh/site-functions/_vhdm >/dev/null"
            ;;
        fish)
            if mkdir -p "$HOME/.config/fish/completions" 2>/dev/null; then
                "$vhdm" completion fish > "$HOME/.config/fish/completions/vhdm.fish"
                log_success "Fish completions installed to ~/.config/fish/completions/vhdm.fish"
                log_info "Or install system-wide with:"
                echo "    sudo mkdir -p /usr/share/fish/vendor_completions.d"
                echo "    vhdm completion fish | sudo tee /usr/share/fish/vendor_completions.d/vhdm.fish >/dev/null"
            fi
            ;;
    esac
}

# Main
main() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     vhdm - WSL VHD Disk Manager       ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    check_wsl
    check_dependencies
    
    local install_dir
    install_dir=$(get_install_dir)
    
    install_from_source "$install_dir"
    setup_completions "$install_dir"
    
    echo ""
    log_success "Installation complete!"
    echo ""
    echo "Quick start:"
    echo "  vhdm --help"
    echo "  vhdm status"
    echo "  vhdm create --vhd-path C:/VMs/disk.vhdx --size 5G --format ext4"
    echo ""
}

main "$@"
