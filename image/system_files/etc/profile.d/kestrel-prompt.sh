# Kestrel OS (DECISIONS.md D27): a short, clean bash prompt, for example "Downloads main ›":
# the current folder in bold, the git branch in grey (only inside a git folder), and a chevron
# in the accent colour that turns red when the last command failed. Over SSH the computer name
# is shown in front. It uses the terminal's own 16 colours, so it fits any colour scheme.
# Only replaces Fedora's default prompt; a prompt set in ~/.bashrc wins.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ -z "${KESTREL_PROMPT_DONE:-}" ]; then
    KESTREL_PROMPT_DONE=1

    # Prints " branch" when the current folder is inside a git repository. It only reads the
    # file .git/HEAD (no git program is started), and it keeps the last command's exit status.
    __kestrel_git() {
        local status=$? dir=$PWD git head
        while [ -n "$dir" ]; do
            git=$dir/.git
            if [ -f "$git" ]; then
                # A worktree or submodule: the file says where the real git folder is.
                read -r head < "$git" 2>/dev/null
                case $head in
                    "gitdir: /"*) git=${head#gitdir: } ;;
                    "gitdir: "*) git=$dir/${head#gitdir: } ;;
                esac
            fi
            if [ -r "$git/HEAD" ]; then
                head=""
                read -r head < "$git/HEAD" 2>/dev/null
                case $head in
                    "ref: refs/heads/"*) printf ' %s' "${head#ref: refs/heads/}" ;;
                    ?*) printf ' %s' "${head:0:7}" ;;
                esac
                break
            fi
            dir=${dir%/*}
        done
        return "$status"
    }

    _kestrel_host=""
    [ -n "${SSH_CONNECTION:-}" ] && _kestrel_host='\[\e[90m\]\h\[\e[0m\] '
    # The text console (Ctrl+Alt+F3) has no "›" character, so it gets ">".
    _kestrel_mark='›'
    [ "${TERM:-}" = linux ] && _kestrel_mark='>'
    PS1="${_kestrel_host}"'\[\e[1m\]\W\[\e[0m\]\[\e[90m\]$(__kestrel_git)\[\e[0m\] \[\e[$(( $? ? 31 : 34 ))m\]'"${_kestrel_mark}"'\[\e[0m\] '
    unset _kestrel_host _kestrel_mark
fi
