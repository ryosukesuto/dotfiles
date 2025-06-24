# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository for managing personal configuration files. The repository contains well-organized configuration files for modern development tools including Zsh, Git, SSH, tmux, Vim, AWS CLI, and GitHub CLI.

## Repository Structure

The repository is organized into logical directories:

- `zsh/` - Modular Zsh configuration files (numbered for load order)
  - `00-base.zsh` - Basic shell options and settings
  - `01-completion.zsh` - Unified completion system configuration (optimized)
  - `10-history.zsh` - History management settings
  - `20-path.zsh` - PATH management using native Zsh arrays
  - `25-aliases.zsh` - Categorized command aliases
  - `30-functions.zsh` - Core functions with lazy loading support
  - `31-aws.zsh`, `32-git.zsh` - Tool-specific configurations
  - `40-tools.zsh` - Version managers and tool initialization (lazy)
  - `50-prompt.zsh` - Custom prompt with caching
  - `functions/` - Lazy-loaded function modules
    - `aws-bastion.zsh` - AWS SSM connection utilities
    - `diagnostics.zsh` - System diagnostic tools
    - `extract.zsh` - Archive extraction utilities
- `git/` - Git configuration with aliases and enhanced settings
- `ssh/` - SSH configuration and management utilities
- `tmux/` - Terminal multiplexer configuration
- `vim/` - Vim editor configuration with plugin management
- `aws/` - AWS CLI configuration templates (secure, no credentials)
- `config/` - Application-specific configurations (GitHub CLI, etc.)
- `.zshrc` - Main Zsh entry point that sources modular files
- `.zprofile` - Zsh profile for environment setup

## Key Tools and Technologies

This setup uses the following tools that may need configuration:

- **Shell**: Zsh with custom peco-src function for directory navigation
- **Version Managers**: pyenv (Python), tfenv (Terraform)
- **Development Tools**: Go, Terraform, DBT (data build tool)
- **Repository Management**: ghq (organizes Git repos under ~/src)
- **Package Manager**: Homebrew (macOS)
- **Cloud Access**: AWS SSM Session Manager for bastion server connections

## Common Tasks

When working with this dotfiles repository:

1. **Installation**: Use `./install.sh` to create symlinks from repository to home directory
2. **Updates**: Modify files in repository and changes are reflected immediately via symlinks
3. **New Machine Setup**: Clone repository and run install script for complete environment setup
4. **Security**: Use template files for sensitive configurations (AWS, etc.)
5. **Local Customization**: Use `.local` files for machine-specific settings not tracked in git
6. **Performance Testing**: Use `path_info` to check PATH configuration, `dotfiles-diag` for system diagnostics
7. **Adding Functions**: Place large or rarely-used functions in `zsh/functions/` for lazy loading

## Architecture Notes

- The user's development setup is focused on cloud development (GCP), data engineering (DBT), and infrastructure (Terraform)
- Git repositories are organized under `~/src` using ghq
- The peco-src function provides quick navigation between projects (supports both fzf and peco)
- AWS SSM functions (`aws-bastion`, `aws-bastion-select`) are lazy-loaded from `functions/aws-bastion.zsh`
- Performance optimizations:
  - Completion system unified in `01-completion.zsh` with lazy loading for detailed styles
  - PATH management uses native Zsh arrays for automatic deduplication
  - Large functions separated into `functions/` directory for on-demand loading
  - Startup time reduced by 30-40% through various optimizations

## Custom Commands

These commands help streamline common tasks in this repository:

### `/setup` - Initial Setup
Initialize or verify the dotfiles installation:
1. Run `./install.sh` if not already executed
2. Check if symlinks are properly created
3. Verify all required tools are installed (Homebrew, pyenv, tfenv, etc.)
4. Report any missing dependencies
5. Suggest next steps for manual configuration (AWS credentials, etc.)

### `/update` - Update Configuration
Update specific configuration files:
- `/update zsh` - Update Zsh configuration files
- `/update git` - Update Git configuration
- `/update aws` - Update AWS configuration templates

### `/check` - Health Check
Verify the integrity of configurations:
1. Check for broken symlinks
2. Validate configuration syntax
3. Ensure no sensitive data in tracked files

### `/optimize` - Performance Optimization
Analyze and optimize shell startup time:
1. Profile Zsh startup time
2. Identify slow-loading modules
3. Suggest optimizations

## Workflow Guidelines

### 1. Configuration Changes
When modifying configuration files:
1. **Plan**: Identify files to modify and their dependencies
2. **Test**: Verify changes in isolated environment if possible
3. **Document**: Update relevant sections in this file
4. **Commit**: Use conventional commit messages

### 2. New Tool Integration
When adding support for a new tool:
1. Create modular configuration file in appropriate directory
2. Update install.sh if symlinks are needed
3. Add tool to Key Tools section above
4. Document any special setup requirements

### 3. Security Considerations
- Never commit credentials or API keys
- Use `.local` files for sensitive configurations
- Review changes for accidental secret exposure
- Use template files with clear placeholders

## Continuous Improvement

### Retrospective Questions
After each significant change, consider:
- Did the change improve workflow efficiency?
- Are there patterns that could be abstracted?
- What documentation needs updating?
- Could this be automated further?

### Performance Metrics
Track and optimize:
- Shell startup time (target: <500ms)
- Command execution speed
- Repository navigation efficiency
- Configuration reload time