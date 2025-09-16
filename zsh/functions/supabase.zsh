#!/usr/bin/env zsh
# Supabase CLI utility functions

# Supabase project switcher
function sb-switch() {
    local project_ref="${1}"
    if [[ -z "${project_ref}" ]]; then
        echo "Usage: sb-switch <project-ref>"
        echo "Switch to a different Supabase project"
        return 1
    fi
    
    echo "Switching to project: ${project_ref}"
    supabase link --project-ref "${project_ref}"
    
    if [[ -f "supabase/.temp/project-ref" ]]; then
        echo "✅ Linked to project: $(cat supabase/.temp/project-ref)"
    fi
}

# Show current Supabase project info
function sb-info() {
    echo "=== Supabase Project Info ==="
    
    # Check if we're in a Supabase project
    if [[ ! -d "supabase" ]]; then
        echo "⚠️  Not in a Supabase project directory"
        return 1
    fi
    
    # Show linked project
    if [[ -f "supabase/.temp/project-ref" ]]; then
        echo "Project Ref: $(cat supabase/.temp/project-ref)"
    else
        echo "Project: Not linked (run 'supabase link')"
    fi
    
    # Show pooler URL if exists
    if [[ -f "supabase/.temp/pooler-url" ]]; then
        echo "Pooler URL: $(cat supabase/.temp/pooler-url)"
    fi
    
    # Check auth status
    if supabase projects list &>/dev/null; then
        echo "Auth Status: ✅ Logged in"
    else
        echo "Auth Status: ❌ Not logged in (run 'supabase login')"
    fi
    
    # Check for environment variables
    if [[ -n "${SUPABASE_ACCESS_TOKEN}" ]]; then
        echo "Access Token: ✅ Set via environment variable"
    fi
    
    if [[ -n "${SUPABASE_URL}" ]]; then
        echo "Supabase URL: ${SUPABASE_URL}"
    fi
}

# List all Supabase projects
function sb-list() {
    echo "=== Your Supabase Projects ==="
    supabase projects list
}

# Supabase database URL helper
function sb-db-url() {
    local password="${1}"
    local project_ref
    
    if [[ -f "supabase/.temp/project-ref" ]]; then
        project_ref=$(cat supabase/.temp/project-ref)
    else
        echo "❌ No project linked. Run 'supabase link' first."
        return 1
    fi
    
    if [[ -z "${password}" ]]; then
        echo "Usage: sb-db-url <password>"
        echo "Generate database connection URL for project: ${project_ref}"
        return 1
    fi
    
    echo "postgresql://postgres:${password}@db.${project_ref}.supabase.co:5432/postgres"
}

# Quick Supabase status check
function sb-status() {
    if ! command -v supabase &>/dev/null; then
        echo "❌ Supabase CLI not installed"
        return 1
    fi
    
    echo "✅ Supabase CLI: $(supabase --version)"
    
    # Check authentication
    if supabase projects list &>/dev/null; then
        echo "✅ Authentication: Logged in"
    else
        echo "⚠️  Authentication: Not logged in"
    fi
    
    # Check current directory
    if [[ -d "supabase" ]]; then
        echo "✅ In Supabase project directory"
        if [[ -f "supabase/.temp/project-ref" ]]; then
            echo "   Linked to: $(cat supabase/.temp/project-ref)"
        else
            echo "   Not linked to any project"
        fi
    else
        echo "ℹ️  Not in a Supabase project directory"
    fi
}

# Clean Supabase temp files
function sb-clean() {
    if [[ -d "supabase/.temp" ]]; then
        echo "Cleaning Supabase temp files..."
        rm -rf supabase/.temp
        echo "✅ Cleaned supabase/.temp directory"
    else
        echo "No temp files to clean"
    fi
}

# Initialize Supabase environment from .env.local
function sb-env() {
    local env_file="${1:-.env.local}"
    
    if [[ ! -f "${env_file}" ]]; then
        echo "❌ Environment file not found: ${env_file}"
        return 1
    fi
    
    echo "Loading Supabase environment from ${env_file}..."
    
    # Export Supabase-related environment variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "${key}" =~ ^#.*$ ]] && continue
        [[ -z "${key}" ]] && continue
        
        # Only export SUPABASE_ variables
        if [[ "${key}" =~ ^SUPABASE_ ]] || [[ "${key}" =~ ^DATABASE_URL ]] || [[ "${key}" =~ ^DIRECT_URL ]]; then
            # Remove quotes if present
            value="${value%\"}"
            value="${value#\"}"
            export "${key}=${value}"
            echo "✅ Exported ${key}"
        fi
    done < "${env_file}"
    
    echo "Environment loaded successfully"
}

# Quick database migration status
function sb-migration-status() {
    echo "=== Migration Status ==="
    supabase migration list
}

# Create a new migration
function sb-migration-new() {
    local name="${1}"
    if [[ -z "${name}" ]]; then
        echo "Usage: sb-migration-new <migration-name>"
        return 1
    fi
    
    supabase migration new "${name}"
}