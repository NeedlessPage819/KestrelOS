# Kestrel OS (DECISIONS.md D27): a short, clean bash prompt: the current folder in the Kestrel
# accent colour and a chevron, for example "Downloads ›". Over SSH the computer name is
# shown in front. Only replaces Fedora's default prompt; a prompt set in ~/.bashrc wins.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ -z "${KESTREL_PROMPT_DONE:-}" ]; then
    KESTREL_PROMPT_DONE=1
    _kestrel_host=""
    [ -n "${SSH_CONNECTION:-}" ] && _kestrel_host='\[\e[2m\]\h \[\e[0m\]'
    PS1="${_kestrel_host}"'\[\e[38;2;141;154;246m\]\W\[\e[0m\] \[\e[38;2;160;160;176m\]›\[\e[0m\] '
    unset _kestrel_host
fi
