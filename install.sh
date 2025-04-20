#!/bin/bash
#
# SSHBuddy Installer Script
# Author: Arash
# Version: 1.0.0
#
# This script installs, updates, or removes the SSHBuddy tool

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default installation locations
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.sshbuddy"
SCRIPT_NAME="sshbuddy"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# Current script directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SOURCE="$CURRENT_DIR/sshbuddy.sh"

# Checks if the script is being run with root/sudo
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${YELLOW}This script requires root privileges for installation in $INSTALL_DIR${NC}"
        echo -e "${YELLOW}Running with sudo...${NC}"
        sudo "$0" "$@"
        exit $?
    fi
}

# Check if the script source file exists
check_source() {
    if [ ! -f "$SCRIPT_SOURCE" ]; then
        echo -e "${RED}Error: Cannot find source file $SCRIPT_SOURCE${NC}"
        echo -e "${YELLOW}Make sure sshbuddy.sh is in the same directory as this installer${NC}"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    # Check for bash
    if ! command -v bash &> /dev/null; then
        echo -e "${RED}[ERROR] bash shell is required but not found.${NC}"
        exit 1
    fi
    
    # Check for ssh
    if ! command -v ssh &> /dev/null; then
        echo -e "${YELLOW}[WARNING] ssh command not found. Please install OpenSSH client.${NC}"
        read -p "Continue anyway? (y/n): " continue_install
        if [[ "$continue_install" != "y" && "$continue_install" != "Y" ]]; then
            exit 1
        fi
    fi
    
    # Check for ssh-copy-id
    if ! command -v ssh-copy-id &> /dev/null; then
        echo -e "${YELLOW}[WARNING] ssh-copy-id command not found. Some features may not work.${NC}"
    fi
    
    # Check for ssh-keygen
    if ! command -v ssh-keygen &> /dev/null; then
        echo -e "${YELLOW}[WARNING] ssh-keygen command not found. Some features may not work.${NC}"
    fi
    
    echo -e "${GREEN}System requirements check completed.${NC}"
}

# Install the script
install_script() {
    echo -e "${BLUE}Installing SSHBuddy...${NC}"
    
    # Create installation directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Copy the script to the installation directory
    cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # Create configuration directory
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        chown -R "$SUDO_USER:$SUDO_USER" "$CONFIG_DIR" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}SSHBuddy installed successfully to $SCRIPT_PATH${NC}"
    echo -e "${BLUE}You can now use it by running:${NC} ${CYAN}sshbuddy${NC}"
}

# Update the script
update_script() {
    echo -e "${BLUE}Updating SSHBuddy...${NC}"
    
    # Check if the script is already installed
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${YELLOW}SSHBuddy is not installed yet. Installing now...${NC}"
        install_script
        return
    fi
    
    # Compare versions
    local current_version=$(grep -o "Version: [0-9.]*" "$SCRIPT_PATH" | cut -d ' ' -f 2)
    local new_version=$(grep -o "Version: [0-9.]*" "$SCRIPT_SOURCE" | cut -d ' ' -f 2)
    
    echo -e "${BLUE}Current version: $current_version${NC}"
    echo -e "${BLUE}New version: $new_version${NC}"
    
    # Simple version comparison (assumes semantic versioning x.y.z)
    if [ "$current_version" = "$new_version" ]; then
        echo -e "${YELLOW}You already have the latest version.${NC}"
        read -p "Do you want to reinstall anyway? (y/n): " force_update
        if [[ "$force_update" != "y" && "$force_update" != "Y" ]]; then
            return
        fi
    fi
    
    # Backup the current version
    local backup_file="$SCRIPT_PATH.backup.$(date '+%Y%m%d%H%M%S')"
    cp "$SCRIPT_PATH" "$backup_file"
    echo -e "${YELLOW}Backup of current version created at $backup_file${NC}"
    
    # Copy the new version
    cp "$SCRIPT_SOURCE" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    echo -e "${GREEN}SSHBuddy updated successfully to version $new_version${NC}"
}

# Remove the script
remove_script() {
    echo -e "${BLUE}Removing SSHBuddy...${NC}"
    
    # Check if the script is installed
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${YELLOW}SSHBuddy is not installed.${NC}"
        return
    fi
    
    # Ask for confirmation
    read -p "Are you sure you want to remove SSHBuddy? (y/n): " confirm_remove
    if [[ "$confirm_remove" != "y" && "$confirm_remove" != "Y" ]]; then
        echo -e "${YELLOW}Removal cancelled.${NC}"
        return
    fi
    
    # Remove the script
    rm "$SCRIPT_PATH"
    
    echo -e "${GREEN}SSHBuddy removed from $SCRIPT_PATH${NC}"
    
    # Ask if user wants to remove configuration files
    read -p "Do you want to remove configuration files as well? (y/n): " remove_config
    if [[ "$remove_config" == "y" || "$remove_config" == "Y" ]]; then
        if [ -d "$CONFIG_DIR" ]; then
            # Backup config files
            local backup_dir="/tmp/sshbuddy_config_backup_$(date '+%Y%m%d%H%M%S')"
            mkdir -p "$backup_dir"
            cp -r "$CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
            echo -e "${YELLOW}Configuration files backed up to $backup_dir${NC}"
            
            # Remove configuration directory
            rm -rf "$CONFIG_DIR"
            echo -e "${GREEN}Configuration files removed from $CONFIG_DIR${NC}"
        else
            echo -e "${YELLOW}No configuration directory found at $CONFIG_DIR${NC}"
        fi
    fi
}

# Show help information
show_help() {
    echo -e "${BLUE}SSHBuddy Installer - Version 1.0.0${NC}"
    echo -e "${BLUE}Author: Arash${NC}\n"
    
    echo -e "${GREEN}Usage:${NC} $0 [command]"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${CYAN}install${NC}    Install SSHBuddy"
    echo -e "  ${CYAN}update${NC}     Update to the latest version"
    echo -e "  ${CYAN}remove${NC}     Remove SSHBuddy"
    echo -e "  ${CYAN}help${NC}       Show this help message"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${CYAN}$0 install${NC}    Install SSHBuddy"
    echo -e "  ${CYAN}$0 update${NC}     Update SSHBuddy"
    echo -e "  ${CYAN}$0 remove${NC}     Remove SSHBuddy"
}

# Main function
main() {
    # Parse command line arguments
    local command="${1:-help}"
    
    case "$command" in
        "install")
            check_source
            check_requirements
            check_root "$@"
            install_script
            ;;
        "update")
            check_source
            check_requirements
            check_root "$@"
            update_script
            ;;
        "remove")
            check_root "$@"
            remove_script
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run the script
main "$@"
