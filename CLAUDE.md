# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository for managing personal configuration files. The repository contains well-organized configuration files for modern development tools including Zsh, Git, SSH, tmux, Vim, AWS CLI, and GitHub CLI.

## Repository Structure

The repository is organized into logical directories:

- `zsh/` - Modular Zsh configuration files (numbered for load order)
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

## Architecture Notes

- The user's development setup is focused on cloud development (GCP), data engineering (DBT), and infrastructure (Terraform)
- Git repositories are organized under `~/src` using ghq
- The peco-src function in .zshrc provides quick navigation between projects
- AWS SSM functions (`aws-bastion`, `aws-bastion-select`) simplify access to bastion servers for RDS connections