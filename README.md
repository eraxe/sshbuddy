# SSHBuddy

A comprehensive SSH management tool for Linux systems.

**Author:** Arash  
**Version:** 1.0.0

## Overview

SSHBuddy is a feature-rich bash script designed to simplify SSH connection management on Linux systems. It helps users manage SSH hosts and connection information, copy SSH keys to remote servers, create connection aliases, and much more.

## Features

- **Profile Management**: Add, edit, list, and remove SSH connection profiles
- **Easy Connections**: Connect to saved profiles with a single command
- **SSH Key Management**: Generate and copy SSH keys to remote servers
- **Alias Support**: Create aliases for frequently used connections
- **SSH Config Integration**: Export/import profiles to/from SSH config
- **Connection Testing**: Test SSH connections before connecting
- **Connection History**: View and analyze connection history
- **User-Friendly Interface**: Colored output and clear instructions

## Installation

### Automatic Installation

1. Clone or download this repository
2. Run the installer:

```bash
chmod +x install.sh
./install.sh install
```

### Manual Installation

1. Copy `sshbuddy.sh` to a location in your PATH (e.g., `/usr/local/bin/sshbuddy`)
2. Make it executable:

```bash
chmod +x /usr/local/bin/sshbuddy
```

## Usage

### Basic Commands

```bash
# Show help
sshbuddy help

# Add a new SSH profile
sshbuddy add

# List all configured profiles
sshbuddy list

# Connect to a profile
sshbuddy connect my-server

# Copy SSH key to a server
sshbuddy copy-id my-server

# Generate a new SSH key
sshbuddy generate-key

# Create an alias for a profile
sshbuddy alias ms my-server

# List all aliases
sshbuddy aliases

# Remove a profile
sshbuddy remove my-server

# Edit a profile
sshbuddy edit my-server

# Test connection to a profile
sshbuddy test my-server

# View connection history
sshbuddy history

# Export profiles to SSH config
sshbuddy export

# Import profiles from SSH config
sshbuddy import

# Show version information
sshbuddy version
```

## Configuration

SSHBuddy stores its configuration files in `~/.sshbuddy/`:

- `config`: Stores SSH connection profiles
- `aliases`: Stores profile aliases
- `history`: Stores connection history

## SSH Config Integration

SSHBuddy can integrate with your existing SSH configuration:

- Export profiles to `~/.ssh/config`
- Import profiles from `~/.ssh/config`

This allows you to use SSHBuddy alongside your existing SSH workflow.

## Updating

To update SSHBuddy to the latest version:

```bash
./install.sh update
```

## Uninstalling

To remove SSHBuddy from your system:

```bash
./install.sh remove
```

## Enhancing SSHBuddy

### Custom Profiles

You can manually edit the `~/.sshbuddy/config` file to create or modify profiles:

```
profile-name:hostname:username:port:identity_file:options
```

### SSH Config Templates

For advanced users, you can create SSH config templates and apply them to multiple servers:

1. Create a template in `~/.sshbuddy/templates/`
2. Reference it when adding or editing profiles

### Scripting

SSHBuddy commands can be used in scripts to automate SSH operations:

```bash
# Example: Test connection and connect if successful
if sshbuddy test my-server > /dev/null; then
    sshbuddy connect my-server
fi
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- OpenSSH project
- Inspiration from various SSH management tools

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
