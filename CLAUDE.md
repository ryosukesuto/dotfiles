# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for managing personal configuration files. Currently, the repository is empty and needs to be populated with configuration files from the home directory.

## Important Configuration Files to Manage

The following configuration files exist in the home directory and should be considered for inclusion:

- `.zshrc` - Zsh shell configuration with PATH exports, custom functions, and tool initializations
- `.zprofile` - Zsh profile that initializes Homebrew
- `.gitconfig` - Git configuration with user settings and ghq root directory
- `.config/` - Directory containing various application configurations

## Key Tools and Technologies

This setup uses the following tools that may need configuration:

- **Shell**: Zsh with custom peco-src function for directory navigation
- **Version Managers**: pyenv (Python), tfenv (Terraform)
- **Development Tools**: Go, Terraform, DBT (data build tool)
- **Repository Management**: ghq (organizes Git repos under ~/src)
- **Package Manager**: Homebrew (macOS)

## Common Tasks

When setting up a dotfiles repository:

1. **Initial Setup**: Copy configuration files from home directory to repository
2. **Symlink Management**: Create symlinks from repository files to their expected locations
3. **Installation Script**: Create a script to automate the setup process on new machines

## Architecture Notes

- The user's development setup is focused on cloud development (GCP), data engineering (DBT), and infrastructure (Terraform)
- Git repositories are organized under `~/src` using ghq
- The peco-src function in .zshrc provides quick navigation between projects