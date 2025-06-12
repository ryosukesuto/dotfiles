# Claude CLI completion for Zsh

# Claude CLI completion function
_claude() {
    local -a opts
    opts=(
        '-d[Enable debug mode]'
        '--debug[Enable debug mode]'
        '--verbose[Override verbose mode setting from config]'
        '-p[Print response and exit (useful for pipes)]'
        '--print[Print response and exit (useful for pipes)]'
        '--output-format[Output format]: :(text json stream-json)'
        '--input-format[Input format]: :(text stream-json)'
        '--model[Specify model to use]'
        '-c[Continue the last conversation]'
        '--continue[Continue the last conversation]'
        '--no-pager[Disable pager]'
        '--version[Show version number]'
        '-h[Show help]'
        '--help[Show help]'
        'settings[Manage settings]'
        'history[Show conversation history]'
        'clear[Clear conversation history]'
    )
    
    _arguments -s $opts
}

# Register the completion function
compdef _claude claude