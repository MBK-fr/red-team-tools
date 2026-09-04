# .bashrc

# ============================================================
# Global definitions
# ============================================================

if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi


# ============================================================
# PATH
# ============================================================

# Add a directory to PATH only if it isn't already present.
path_add() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# User binaries
path_add "$HOME/.local/bin"
path_add "$HOME/bin"

# Go
path_add "$HOME/go/bin"

# Nim
path_add "$HOME/.nimble/bin"

# Gradle
path_add "/opt/gradle/bin"

# Metasploit
path_add "/opt/metasploit-framework/bin"

# Android SDK
export ANDROID_HOME="$HOME/Utilities/Android/Sdk"
path_add "$ANDROID_HOME/tools"
path_add "$ANDROID_HOME/tools/bin"
path_add "$ANDROID_HOME/platform-tools"

export PATH


# ============================================================
# Mise
# ============================================================

# Mise manages Python, Ruby, Rust, Node, etc.
eval "$(mise activate bash)"


# ============================================================
# History
# ============================================================

# Better history behavior:
# Prevent duplicate spam, preserve history across sessions,
# and clean duplicate command recall.
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend


# ============================================================
# Shell behavior
# ============================================================

# Case-insensitive globbing
shopt -s nocaseglob

# Fix small typos in cd
shopt -s cdspell

# Auto cd (type folder name directly)
# shopt -s autocd


# ============================================================
# User-specific aliases and functions
# ============================================================

if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc


# ============================================================
# Python
# ============================================================

# Prevent Python from creating __pycache__ / .pyc files
export PYTHONDONTWRITEBYTECODE=1


# ============================================================
# GPG agent
# ============================================================

export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null


# ============================================================
# Starship
# ============================================================

eval "$(starship init bash)"


# ============================================================
# fzf
# ============================================================

eval "$(fzf --bash)"


# ============================================================
# zoxide
# ============================================================

eval "$(zoxide init bash)"


# ============================================================
# Custom commands
# ============================================================

# desc: Reverse DNS lookup via THC's public IP tool
rdns() {
    curl -m10 -fsSL "https://ip.thc.org/${1:?}?limit=20&f=${2}"
}


# desc: Lists all open ports with visibility (Public/Private/Loopback)
function ports() {
    sudo ss -tulnp | awk '
    BEGIN {
        print "\033[1;36mProto\tState\tPort\t\tVisibility\tAddress\t\tProcess\033[0m"
    }
    NR>1 {
        split($5,a,":")
        port=a[length(a)]
        addr=a[1]
        gsub(/users:\(\("?/,"",$7)
        gsub(/\)\)/,"",$7)

        # determine color and visibility
        if (addr == "127.0.0.1" || addr == "::1") {
            color="\033[1;31m"; vis="Loopback"
        } else if (addr == "0.0.0.0" || addr == "::" || addr == "*") {
            color="\033[1;32m"; vis="Public"
        } else {
            color="\033[1;33m"; vis="Private"
        }

        printf "%s%-5s\033[0m\t%-7s\t%-8s\t%-10s\t%-15s\t%s\n", color, $1, $2, port, vis, addr, $7
    }'
}


# ============================================================
# SSH host autocomplete
# ============================================================

_ssh_completion() {
    local SSH_FILES=()

    for f in "$HOME/.ssh/config" "$HOME/.ssh/config.local"; do
        [ -e "$f" ] && SSH_FILES+=("$f")
    done

    if [ "${#SSH_FILES[@]}" -ne 0 ]; then
        complete -o default -o nospace \
            -W "$(awk '/^Host\s+/{ print $2 }' "${SSH_FILES[@]}")" \
            ssh scp sftp
    fi
}

_ssh_completion
unset _ssh_completion


# ============================================================
# ripgrep + fzf
# ============================================================

# desc: Search inside files with preview (rg + fzf)
rgi() {
    rg --line-number --color=always --smart-case "${1:-}" |
        fzf --ansi \
            --preview 'bat --style=numbers --color=always {1} --line-range {2}:+20' \
            --delimiter ':' \
            --nth 3..
}


# ============================================================
# Help menu
# ============================================================

# desc: Mini terminal help menu
function helpme() {
    echo -e "\n\033[1;36m🧩  Custom Commands, Functions, and Aliases Loaded in This Shell:\033[0m\n"

    # === Aliases ===
    echo -e "\033[1;33mAliases:\033[0m"

    awk '
        /^alias / {
            aliasName=$2
            sub(/=.*/, "", aliasName)
            print aliasName
        }
    ' ~/.bashrc | while read -r a; do

        desc=$(awk -v alias="$a" '
            $0 ~ "alias "alias"=" {
                if (NR > 1 && prev ~ /^# desc:/) {
                    sub(/^# desc:[[:space:]]*/, "", prev)
                    print prev
                    exit
                }
            }
            {prev=$0}
        ' ~/.bashrc)

        [ -z "$desc" ] && desc="(no description)"

        echo -e "  \033[1;32m$a\033[0m  -  $desc"
    done

    echo ""

    # === Functions ===
    echo -e "\033[1;33mFunctions:\033[0m"

    declare -F | awk '{print $3}' | while read -r func; do

        desc=$(awk -v fn="$func" '
            $0 ~ "(function[[:space:]]+"fn"\\(\\)|^"fn"\\(\\))" {
                if (NR > 1 && prev ~ /^# desc:/) {
                    sub(/^# desc:[[:space:]]*/, "", prev)
                    print prev
                    exit
                }
            }
            {prev=$0}
        ' ~/.bashrc)

        [ -z "$desc" ] && desc="(no description)"

        echo -e "  \033[1;35m$func\033[0m  -  $desc"
    done

    echo ""

    echo -e "\033[1;34mUsage:\033[0m"
    echo -e "  Type the alias or function name directly to use it."
    echo -e "  Example: \033[1;32mports\033[0m  → Show open ports with visibility."
    echo -e "  Example: \033[1;32mrdns 8.8.8.8\033[0m  → Reverse DNS lookup."
    echo -e "  Pipe with other commands: \033[1;32mports | grep \"Public\"\033[0m"

    echo ""
    echo -e "\033[1;90mHint:\033[0m Add '# desc: your description' above any alias/function in ~/.bashrc to include it automatically.\n"
}

