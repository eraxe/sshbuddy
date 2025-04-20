#!/bin/bash
#
# SSHBuddy - A comprehensive SSH management tool
# Author: Arash
# Version: 1.0.0
#
# This tool helps to:
# - Manage SSH hosts and connection information
# - Copy SSH keys to remote servers
# - Create and manage connection aliases
# - View connection history and statistics
# - Test SSH connections

# Configuration file paths
CONFIG_DIR="$HOME/.sshbuddy"
CONFIG_FILE="$CONFIG_DIR/config"
ALIASES_FILE="$CONFIG_DIR/aliases"
HISTORY_FILE="$CONFIG_DIR/history"
SSH_CONFIG_FILE="$HOME/.ssh/config"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure configuration directory exists
ensure_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        touch "$CONFIG_FILE"
        touch "$ALIASES_FILE"
        touch "$HISTORY_FILE"
        echo "Configuration directory created at $CONFIG_DIR"
    fi
    
    # Ensure SSH directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    
    # Ensure SSH config file exists
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        touch "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
    fi
}

# Display help information
show_help() {
    echo -e "${BLUE}SSHBuddy - SSH Management Tool${NC}"
    echo -e "${BLUE}Author: Arash${NC}"
    echo -e "${BLUE}Version: 1.0.0${NC}\n"
    
    echo -e "${GREEN}Usage:${NC} sshbuddy [command] [options]"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${CYAN}add${NC}                    Add a new SSH connection profile"
    echo -e "  ${CYAN}list${NC}                   List all configured SSH profiles"
    echo -e "  ${CYAN}connect <name>${NC}         Connect to a saved profile"
    echo -e "  ${CYAN}copy-id <name>${NC}         Copy SSH key to a remote server"
    echo -e "  ${CYAN}generate-key${NC}           Generate a new SSH key pair"
    echo -e "  ${CYAN}alias <name> <command>${NC} Create an alias for a connection"
    echo -e "  ${CYAN}aliases${NC}                List all connection aliases"
    echo -e "  ${CYAN}remove <name>${NC}          Remove a profile"
    echo -e "  ${CYAN}edit <name>${NC}            Edit a profile"
    echo -e "  ${CYAN}test <name>${NC}            Test connection to a profile"
    echo -e "  ${CYAN}history${NC}                Show connection history"
    echo -e "  ${CYAN}export${NC}                 Export profiles to SSH config"
    echo -e "  ${CYAN}import${NC}                 Import profiles from SSH config"
    echo -e "  ${CYAN}version${NC}                Show version information"
    echo -e "  ${CYAN}help${NC}                   Show this help message"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${CYAN}sshbuddy add${NC}           Interactive prompts to add a new connection"
    echo -e "  ${CYAN}sshbuddy connect server1${NC} Connect to server named 'server1'"
    echo -e "  ${CYAN}sshbuddy alias s1 server1${NC} Create alias 's1' for 'server1'"
}

# Add a new connection profile
add_profile() {
    echo -e "${BLUE}Adding a new SSH profile...${NC}"
    
    # Get host info
    read -p "Enter profile name (e.g., work-server): " name
    read -p "Enter hostname or IP address: " host
    read -p "Enter username: " user
    read -p "Enter port (default: 22): " port
    port=${port:-22}
    read -p "Enter identity file path (leave blank for default): " identity_file
    read -p "Additional SSH options (leave blank if none): " options
    
    # Check if profile already exists
    if grep -q "^$name:" "$CONFIG_FILE"; then
        echo -e "${RED}Profile '$name' already exists. Use 'edit' command to modify it.${NC}"
        return 1
    fi
    
    # Save the profile
    echo "$name:$host:$user:$port:$identity_file:$options" >> "$CONFIG_FILE"
    echo -e "${GREEN}Profile '$name' added successfully!${NC}"
    
    # Ask if the user wants to add this to SSH config
    read -p "Do you want to add this profile to SSH config? (y/n): " add_to_ssh_config
    if [[ "$add_to_ssh_config" == "y" || "$add_to_ssh_config" == "Y" ]]; then
        add_to_ssh_config "$name"
    fi
    
    # Ask if the user wants to copy SSH key
    read -p "Do you want to copy your SSH key to this server? (y/n): " copy_key
    if [[ "$copy_key" == "y" || "$copy_key" == "Y" ]]; then
        copy_ssh_id "$name"
    fi
}

# List all profiles
list_profiles() {
    echo -e "${BLUE}Available SSH profiles:${NC}"
    echo -e "${YELLOW}-------------------------------------${NC}"
    echo -e "${CYAN}NAME\tHOST\t\tUSER\tPORT${NC}"
    echo -e "${YELLOW}-------------------------------------${NC}"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}No profiles found. Use 'add' command to create one.${NC}"
        return
    fi
    
    while IFS=: read -r name host user port identity options; do
        echo -e "${GREEN}$name${NC}\t${host}\t${user}\t${port}"
    done < "$CONFIG_FILE"
}

# Connect to a saved profile
connect_profile() {
    local profile_name="$1"
    
    # Check if profile name is provided
    if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name is required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy connect <profile-name>${NC}"
        return 1
    fi
    
    # Check alias first
    local alias_target=""
    if [ -f "$ALIASES_FILE" ]; then
        alias_target=$(grep "^$profile_name:" "$ALIASES_FILE" | cut -d: -f2)
        if [ -n "$alias_target" ]; then
            profile_name="$alias_target"
        fi
    fi
    
    # Find the profile
    local profile=$(grep "^$profile_name:" "$CONFIG_FILE")
    
    if [ -z "$profile" ]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Extract connection details
    IFS=: read -r name host user port identity options <<< "$profile"
    
    # Build SSH command
    ssh_cmd="ssh"
    
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        ssh_cmd="$ssh_cmd -p $port"
    fi
    
    if [ -n "$identity" ]; then
        ssh_cmd="$ssh_cmd -i $identity"
    fi
    
    if [ -n "$options" ]; then
        ssh_cmd="$ssh_cmd $options"
    fi
    
    ssh_cmd="$ssh_cmd $user@$host"
    
    # Log connection to history
    echo "$(date '+%Y-%m-%d %H:%M:%S'):$name:$host" >> "$HISTORY_FILE"
    
    # Connect
    echo -e "${GREEN}Connecting to $name ($user@$host)...${NC}"
    echo -e "${BLUE}$ssh_cmd${NC}"
    eval "$ssh_cmd"
}

# Copy SSH key to remote server
copy_ssh_id() {
    local profile_name="$1"
    
    # Check if profile name is provided
    if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name is required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy copy-id <profile-name>${NC}"
        return 1
    fi
    
    # Find the profile
    local profile=$(grep "^$profile_name:" "$CONFIG_FILE")
    
    if [ -z "$profile" ]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Extract connection details
    IFS=: read -r name host user port identity options <<< "$profile"
    
    # Check if identity file exists, if not use default
    local key_path="$HOME/.ssh/id_rsa.pub"
    if [ -n "$identity" ] && [ -f "${identity}.pub" ]; then
        key_path="${identity}.pub"
    elif [ ! -f "$key_path" ]; then
        echo -e "${YELLOW}No SSH key found. Generating a new one...${NC}"
        generate_ssh_key
        key_path="$HOME/.ssh/id_rsa.pub"
    fi
    
    # Build ssh-copy-id command
    copy_cmd="ssh-copy-id"
    
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        copy_cmd="$copy_cmd -p $port"
    fi
    
    if [ -f "$key_path" ]; then
        copy_cmd="$copy_cmd -i $key_path"
    else
        echo -e "${RED}SSH public key not found at $key_path${NC}"
        return 1
    fi
    
    copy_cmd="$copy_cmd $user@$host"
    
    # Copy the key
    echo -e "${GREEN}Copying SSH key to $name ($user@$host)...${NC}"
    echo -e "${BLUE}$copy_cmd${NC}"
    eval "$copy_cmd"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSH key successfully copied to $host${NC}"
    else
        echo -e "${RED}Failed to copy SSH key to $host${NC}"
    fi
}

# Generate SSH key
generate_ssh_key() {
    echo -e "${BLUE}Generating a new SSH key pair...${NC}"
    
    read -p "Enter file name (default: id_rsa): " key_name
    key_name=${key_name:-id_rsa}
    key_path="$HOME/.ssh/$key_name"
    
    read -p "Enter key comment (email/identifier): " key_comment
    key_comment=${key_comment:-$(whoami)@$(hostname)}
    
    ssh-keygen -t rsa -b 4096 -f "$key_path" -C "$key_comment"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSH key pair generated successfully at:${NC}"
        echo -e "${CYAN}$key_path${NC} (private key)"
        echo -e "${CYAN}$key_path.pub${NC} (public key)"
        chmod 600 "$key_path"
        chmod 644 "$key_path.pub"
    else
        echo -e "${RED}Failed to generate SSH key pair.${NC}"
    fi
}

# Create connection alias
create_alias() {
    local alias_name="$1"
    local profile_name="$2"
    
    # Check if both alias and profile names are provided
    if [ -z "$alias_name" ] || [ -z "$profile_name" ]; then
        echo -e "${RED}Both alias name and profile name are required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy alias <alias-name> <profile-name>${NC}"
        return 1
    fi
    
    # Check if profile exists
    if ! grep -q "^$profile_name:" "$CONFIG_FILE"; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Remove any existing alias with the same name
    if [ -f "$ALIASES_FILE" ]; then
        sed -i "/^$alias_name:/d" "$ALIASES_FILE"
    fi
    
    # Add the alias
    echo "$alias_name:$profile_name" >> "$ALIASES_FILE"
    echo -e "${GREEN}Alias '$alias_name' created for profile '$profile_name'${NC}"
}

# List all aliases
list_aliases() {
    echo -e "${BLUE}Available connection aliases:${NC}"
    echo -e "${YELLOW}-------------------------------------${NC}"
    echo -e "${CYAN}ALIAS\tPROFILE${NC}"
    echo -e "${YELLOW}-------------------------------------${NC}"
    
    if [ ! -s "$ALIASES_FILE" ]; then
        echo -e "${RED}No aliases found. Use 'alias' command to create one.${NC}"
        return
    fi
    
    while IFS=: read -r alias_name profile_name; do
        echo -e "${GREEN}$alias_name${NC}\t${profile_name}"
    done < "$ALIASES_FILE"
}

# Remove a profile
remove_profile() {
    local profile_name="$1"
    
    # Check if profile name is provided
    if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name is required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy remove <profile-name>${NC}"
        return 1
    fi
    
    # Check if profile exists
    if ! grep -q "^$profile_name:" "$CONFIG_FILE"; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Remove from config file
    sed -i "/^$profile_name:/d" "$CONFIG_FILE"
    
    # Remove aliases pointing to this profile
    if [ -f "$ALIASES_FILE" ]; then
        while IFS=: read -r alias_name target_profile; do
            if [ "$target_profile" = "$profile_name" ]; then
                sed -i "/^$alias_name:/d" "$ALIASES_FILE"
                echo -e "${YELLOW}Removed alias '$alias_name' pointing to '$profile_name'${NC}"
            fi
        done < "$ALIASES_FILE"
    fi
    
    echo -e "${GREEN}Profile '$profile_name' removed successfully!${NC}"
    
    # Ask if user wants to remove from SSH config
    read -p "Do you want to remove this profile from SSH config? (y/n): " remove_from_ssh
    if [[ "$remove_from_ssh" == "y" || "$remove_from_ssh" == "Y" ]]; then
        remove_from_ssh_config "$profile_name"
    fi
}

# Edit a profile
edit_profile() {
    local profile_name="$1"
    
    # Check if profile name is provided
    if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name is required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy edit <profile-name>${NC}"
        return 1
    fi
    
    # Find the profile
    local profile=$(grep "^$profile_name:" "$CONFIG_FILE")
    
    if [ -z "$profile" ]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Extract existing values
    IFS=: read -r name host user port identity options <<< "$profile"
    
    echo -e "${BLUE}Editing profile '$name'${NC}"
    echo -e "${YELLOW}(Press Enter to keep current value)${NC}"
    
    read -p "Hostname [$host]: " new_host
    new_host=${new_host:-$host}
    
    read -p "Username [$user]: " new_user
    new_user=${new_user:-$user}
    
    read -p "Port [$port]: " new_port
    new_port=${new_port:-$port}
    
    read -p "Identity file [$identity]: " new_identity
    new_identity=${new_identity:-$identity}
    
    read -p "Options [$options]: " new_options
    new_options=${new_options:-$options}
    
    # Update the profile
    sed -i "s|^$name:.*$|$name:$new_host:$new_user:$new_port:$new_identity:$new_options|" "$CONFIG_FILE"
    
    echo -e "${GREEN}Profile '$name' updated successfully!${NC}"
    
    # Ask if the user wants to update SSH config
    read -p "Do you want to update this profile in SSH config? (y/n): " update_ssh
    if [[ "$update_ssh" == "y" || "$update_ssh" == "Y" ]]; then
        remove_from_ssh_config "$name"
        add_to_ssh_config "$name"
    fi
}

# Test connection to a profile
test_connection() {
    local profile_name="$1"
    
    # Check if profile name is provided
    if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name is required.${NC}"
        echo -e "Usage: ${CYAN}sshbuddy test <profile-name>${NC}"
        return 1
    fi
    
    # Check alias first
    local alias_target=""
    if [ -f "$ALIASES_FILE" ]; then
        alias_target=$(grep "^$profile_name:" "$ALIASES_FILE" | cut -d: -f2)
        if [ -n "$alias_target" ]; then
            profile_name="$alias_target"
        fi
    fi
    
    # Find the profile
    local profile=$(grep "^$profile_name:" "$CONFIG_FILE")
    
    if [ -z "$profile" ]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Extract connection details
    IFS=: read -r name host user port identity options <<< "$profile"
    
    echo -e "${BLUE}Testing connection to $name ($user@$host)...${NC}"
    
    # Build SSH command for testing
    ssh_cmd="ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no"
    
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        ssh_cmd="$ssh_cmd -p $port"
    fi
    
    if [ -n "$identity" ]; then
        ssh_cmd="$ssh_cmd -i $identity"
    fi
    
    ssh_cmd="$ssh_cmd $user@$host exit"
    
    # Execute the test
    eval "$ssh_cmd" > /dev/null 2>&1
    local status=$?
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}Connection successful!${NC}"
        return 0
    else
        echo -e "${RED}Connection failed!${NC}"
        echo -e "${YELLOW}Troubleshooting tips:${NC}"
        echo -e "- Check if the server is running and accessible"
        echo -e "- Verify your username and host are correct"
        echo -e "- Make sure your SSH key is properly set up"
        echo -e "- Check if port $port is open and SSH is running on it"
        return 1
    fi
}

# Show connection history
show_history() {
    echo -e "${BLUE}Connection history:${NC}"
    echo -e "${YELLOW}------------------------------------------${NC}"
    echo -e "${CYAN}DATE\t\tTIME\tPROFILE\tHOST${NC}"
    echo -e "${YELLOW}------------------------------------------${NC}"
    
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${RED}No connection history found.${NC}"
        return
    fi
    
    # Show last 10 connections by default
    local count=${1:-10}
    
    tail -n "$count" "$HISTORY_FILE" | while IFS=: read -r datetime name host; do
        date=$(echo "$datetime" | cut -d' ' -f1)
        time=$(echo "$datetime" | cut -d' ' -f2)
        echo -e "${date}\t${time}\t${GREEN}${name}${NC}\t${host}"
    done
    
    # Show stats
    echo -e "\n${BLUE}Connection statistics:${NC}"
    echo -e "${YELLOW}------------------------------------------${NC}"
    echo -e "${CYAN}PROFILE\tCONNECTIONS${NC}"
    echo -e "${YELLOW}------------------------------------------${NC}"
    
    # Count connections by profile
    cat "$HISTORY_FILE" | cut -d: -f2 | sort | uniq -c | sort -nr | while read -r count profile; do
        echo -e "${GREEN}${profile}${NC}\t${count}"
    done
}

# Export profiles to SSH config
export_to_ssh_config() {
    echo -e "${BLUE}Exporting profiles to SSH config...${NC}"
    
    # Check if any profiles exist
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}No profiles found to export.${NC}"
        return 1
    fi
    
    # Backup existing SSH config
    local backup_file="$SSH_CONFIG_FILE.backup.$(date '+%Y%m%d%H%M%S')"
    cp "$SSH_CONFIG_FILE" "$backup_file"
    echo -e "${YELLOW}Backup of SSH config created at $backup_file${NC}"
    
    # Ask if user wants to replace or append
    read -p "Do you want to replace existing SSH config or append to it? (replace/append): " export_mode
    
    if [[ "$export_mode" == "replace" ]]; then
        # Add header to new config
        echo "# SSH config generated by SSHBuddy on $(date)" > "$SSH_CONFIG_FILE"
        echo "# Original config backed up to $backup_file" >> "$SSH_CONFIG_FILE"
        echo "" >> "$SSH_CONFIG_FILE"
    else
        # Add separator
        echo "" >> "$SSH_CONFIG_FILE"
        echo "# SSHBuddy profiles added on $(date)" >> "$SSH_CONFIG_FILE"
        echo "" >> "$SSH_CONFIG_FILE"
    fi
    
    # Export each profile
    while IFS=: read -r name host user port identity options; do
        echo "Host $name" >> "$SSH_CONFIG_FILE"
        echo "    HostName $host" >> "$SSH_CONFIG_FILE"
        echo "    User $user" >> "$SSH_CONFIG_FILE"
        
        if [ -n "$port" ] && [ "$port" != "22" ]; then
            echo "    Port $port" >> "$SSH_CONFIG_FILE"
        fi
        
        if [ -n "$identity" ]; then
            echo "    IdentityFile $identity" >> "$SSH_CONFIG_FILE"
        fi
        
        if [ -n "$options" ]; then
            # Split options by space and add each
            for option in $options; do
                key=$(echo "$option" | cut -d= -f1)
                value=$(echo "$option" | cut -d= -f2)
                echo "    $key $value" >> "$SSH_CONFIG_FILE"
            done
        fi
        
        echo "" >> "$SSH_CONFIG_FILE"
        
    done < "$CONFIG_FILE"
    
    chmod 600 "$SSH_CONFIG_FILE"
    echo -e "${GREEN}Profiles successfully exported to $SSH_CONFIG_FILE${NC}"
}

# Import profiles from SSH config
import_from_ssh_config() {
    echo -e "${BLUE}Importing profiles from SSH config...${NC}"
    
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        echo -e "${RED}SSH config file not found at $SSH_CONFIG_FILE${NC}"
        return 1
    fi
    
    # Backup existing profiles
    local backup_file="$CONFIG_FILE.backup.$(date '+%Y%m%d%H%M%S')"
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${YELLOW}Backup of profiles created at $backup_file${NC}"
    fi
    
    # Ask if user wants to replace or append
    read -p "Do you want to replace existing profiles or append new ones? (replace/append): " import_mode
    
    if [[ "$import_mode" == "replace" ]]; then
        # Clear existing profiles
        > "$CONFIG_FILE"
    fi
    
    # Parse SSH config file
    local current_host=""
    local hostname=""
    local user=""
    local port="22"
    local identity=""
    local options=""
    local imported_count=0
    
    while IFS= read -r line; do
        # Trim leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi
        
        # Check for Host declaration
        if [[ "$line" =~ ^Host[[:space:]]+(.*) ]]; then
            # Save previous host if we had one
            if [ -n "$current_host" ] && [ -n "$hostname" ]; then
                # Check if profile already exists
                if ! grep -q "^$current_host:" "$CONFIG_FILE"; then
                    echo "$current_host:$hostname:$user:$port:$identity:$options" >> "$CONFIG_FILE"
                    imported_count=$((imported_count + 1))
                    echo -e "${GREEN}Imported profile: $current_host${NC}"
                fi
            fi
            
            # Start new host
            current_host="${BASH_REMATCH[1]}"
            # Skip wildcard hosts and patterns with *
            if [[ "$current_host" == *\** ]]; then
                current_host=""
                continue
            fi
            
            # Reset values for new host
            hostname=""
            user=""
            port="22"
            identity=""
            options=""
            
        # Parse host properties if we have a current host
        elif [ -n "$current_host" ]; then
            # Convert to lowercase for case-insensitive matching
            local lc_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
            
            if [[ "$lc_line" =~ ^[[:space:]]*hostname[[:space:]]+(.*) ]]; then
                hostname="${BASH_REMATCH[1]}"
            elif [[ "$lc_line" =~ ^[[:space:]]*user[[:space:]]+(.*) ]]; then
                user="${BASH_REMATCH[1]}"
            elif [[ "$lc_line" =~ ^[[:space:]]*port[[:space:]]+(.*) ]]; then
                port="${BASH_REMATCH[1]}"
            elif [[ "$lc_line" =~ ^[[:space:]]*identityfile[[:space:]]+(.*) ]]; then
                identity="${BASH_REMATCH[1]}"
            # Collect other options
            elif [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+(.+) ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                # Skip hostname, user, port and identityfile as they're handled separately
                if [[ "$key" != "HostName" && "$key" != "User" && "$key" != "Port" && "$key" != "IdentityFile" ]]; then
                    if [ -n "$options" ]; then
                        options="$options $key=$value"
                    else
                        options="$key=$value"
                    fi
                fi
            fi
        fi
    done < "$SSH_CONFIG_FILE"
    
    # Save the last host
    if [ -n "$current_host" ] && [ -n "$hostname" ]; then
        if ! grep -q "^$current_host:" "$CONFIG_FILE"; then
            echo "$current_host:$hostname:$user:$port:$identity:$options" >> "$CONFIG_FILE"
            imported_count=$((imported_count + 1))
            echo -e "${GREEN}Imported profile: $current_host${NC}"
        fi
    fi
    
    if [ $imported_count -eq 0 ]; then
        echo -e "${YELLOW}No new profiles found to import.${NC}"
    else
        echo -e "${GREEN}Successfully imported $imported_count profiles.${NC}"
    fi
}

# Add profile to SSH config
add_to_ssh_config() {
    local profile_name="$1"
    
    # Find the profile
    local profile=$(grep "^$profile_name:" "$CONFIG_FILE")
    
    if [ -z "$profile" ]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi
    
    # Extract connection details
    IFS=: read -r name host user port identity options <<< "$profile"
    
    # Check if profile already exists in SSH config
    if grep -q "^Host $name$" "$SSH_CONFIG_FILE"; then
        echo -e "${YELLOW}Profile '$name' already exists in SSH config. Removing it first...${NC}"
        remove_from_ssh_config "$name"
    fi
    
    # Add to SSH config
    echo "" >> "$SSH_CONFIG_FILE"
    echo "# Added by SSHBuddy on $(date)" >> "$SSH_CONFIG_FILE"
    echo "Host $name" >> "$SSH_CONFIG_FILE"
    echo "    HostName $host" >> "$SSH_CONFIG_FILE"
    echo "    User $user" >> "$SSH_CONFIG_FILE"
    
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        echo "    Port $port" >> "$SSH_CONFIG_FILE"
    fi
    
    if [ -n "$identity" ]; then
        echo "    IdentityFile $identity" >> "$SSH_CONFIG_FILE"
    fi
    
    if [ -n "$options" ]; then
        # Split options by space and add each
        for option in $options; do
            key=$(echo "$option" | cut -d= -f1)
            value=$(echo "$option" | cut -d= -f2)
            echo "    $key $value" >> "$SSH_CONFIG_FILE"
        done
    fi
    
    chmod 600 "$SSH_CONFIG_FILE"
    echo -e "${GREEN}Profile '$name' added to SSH config.${NC}"
}

# Remove profile from SSH config
remove_from_ssh_config() {
    local profile_name="$1"
    
    # Check if profile exists in SSH config
    if ! grep -q "^Host $profile_name$" "$SSH_CONFIG_FILE"; then
        echo -e "${YELLOW}Profile '$profile_name' not found in SSH config.${NC}"
        return 0
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Find the Host section and remove it along with its settings
    local in_section=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^Host[[:space:]]+$profile_name$ ]]; then
            in_section=1
            continue
        elif [[ "$in_section" -eq 1 && "$line" =~ ^Host[[:space:]]+ ]]; then
            in_section=0
        fi
        
        if [[ "$in_section" -eq 0 ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$SSH_CONFIG_FILE"
    
    # Replace original with modified file
    mv "$temp_file" "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"
    
    echo -e "${GREEN}Profile '$profile_name' removed from SSH config.${NC}"
}

# Show version information
show_version() {
    echo -e "${BLUE}SSHBuddy - SSH Management Tool${NC}"
    echo -e "${BLUE}Author: Arash${NC}"
    echo -e "${BLUE}Version: 1.0.0${NC}"
    echo -e "${YELLOW}https://github.com/arash/sshbuddy${NC}"
}

# Verify system requirements
verify_system_requirements() {
    local requirements_met=true
    
    # Check for ssh
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}[ERROR] ssh command not found. Please install OpenSSH client.${NC}"
        requirements_met=false
    fi
    
    # Check for ssh-copy-id
    if ! command -v ssh-copy-id &> /dev/null; then
        echo -e "${YELLOW}[WARNING] ssh-copy-id command not found. Key copying will not work.${NC}"
    fi
    
    # Check for ssh-keygen
    if ! command -v ssh-keygen &> /dev/null; then
        echo -e "${YELLOW}[WARNING] ssh-keygen command not found. Key generation will not work.${NC}"
    fi
    
    return $requirements_met
}

# Main function
main() {
    # Ensure configuration directory exists
    ensure_config_dir
    
    # Verify system requirements
    verify_system_requirements
    
    # Parse command line arguments
    local command="$1"
    shift
    
    case "$command" in
        "add")
            add_profile
            ;;
        "list")
            list_profiles
            ;;
        "connect")
            connect_profile "$1"
            ;;
        "copy-id")
            copy_ssh_id "$1"
            ;;
        "generate-key")
            generate_ssh_key
            ;;
        "alias")
            create_alias "$1" "$2"
            ;;
        "aliases")
            list_aliases
            ;;
        "remove")
            remove_profile "$1"
            ;;
        "edit")
            edit_profile "$1"
            ;;
        "test")
            test_connection "$1"
            ;;
        "history")
            show_history "$1"
            ;;
        "export")
            export_to_ssh_config
            ;;
        "import")
            import_from_ssh_config
            ;;
        "version")
            show_version
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            if [ -z "$command" ]; then
                show_help
            else
                echo -e "${RED}Unknown command: $command${NC}"
                show_help
            fi
            ;;
    esac
}

# Run the script
main "$@"
