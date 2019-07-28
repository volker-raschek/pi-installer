#  ~/.bashrc
#

# If not running interactively, don't do anything
 [[ $- != *i* ]] && return

# Bash settings
shopt -s globstar                                                         # activate globstar option
shopt -s histappend                                                       # activate append history

# XDG Base Directory
export XDG_CONFIG_HOME="${HOME}/.config"                                  # FreeDesktop - config directory for programms
export XDG_CACHE_HOME="${HOME}/.cache"                                    # FreeDesktop - cache directory for programms
export XDG_DATA_HOME="${HOME}/.local/share"                               # FreeDesktop - home directory of programm data

# Sources
[ -f "${XDG_DATA_HOME}/bash/git" ] && source "${XDG_DATA_HOME}/bash/git"  # git bash-completion and prompt functions

# XDG Base Directory Configs
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"                               # gpg (home dir)
export HISTCONTROL="ignoreboth"                                           # Don't put duplicate lines or starting with spaces in the history
export HISTSIZE="1000"                                                    # Max lines in bash history # Append 2000 lines after closing sessions
export HISTFILE="${XDG_DATA_HOME}/bash/history"                           # Location of bash history file
export HISTFILESIZE="2000"                                                # Max lines in bash history
export LESSHISTFILE="${XDG_CACHE_HOME}/less/history"                      # less history (home dir)
export LESSKEY="${XDG_CONFIG_HOME}/less/lesskey"                          # less

# Programm Settings
export EDITOR="vim"                                                       # default editor (no full-screen)
export GIT_PS1_SHOWDIRTYSTATE=" "                                         # Enable, if git shows in prompt staged (+) or unstaged(*) states
export GIT_PS1_SHOWSTASHSTATE=" "                                         # Enable, if git shows in prompt stashed ($) states
export GIT_PS1_SHOWUNTRACKEDFILES=" "                                     # Enable, if git shows in prompt untracked (%) states
export GIT_PS1_SHOWUPSTREAM=" "                                           # Enable, if git shows in prompt behind(<), ahead(>) or diverges(<>) from upstream
export PS1='\u@\h:\w\$ '                                                  # Bash prompt with git
export VISUAL="vim"                                                       # default editor (full-screen)

# General Aliases
alias ..='cd ..'
alias ...='cd ../..'
alias cps='cp --sparse=never'                                             # copy paste files without sparse
alias duha='du -h --apparent-size'                                        # Show real file size (sparse size)
alias ghistory='history | grep'                                           # Shortcut to grep in history
alias gpg-dane='gpg --auto-key-locate dane --trust-model always -ear'     # This is for a pipe to encrypt a file
alias ipt='sudo iptables -L -n -v --line-numbers'                         # Show all iptable rules
alias ports='ss -atun'                                                    # List all open ports from localhost

# Aliases for pacman
alias iap='pacman --query --info'                                         # Pacman: Information-About-Package
alias lao='pacman --query --deps --unrequired'                            # Pacman: List-All-Orphans
alias uap='pacman --sync --refresh --sysupgrade'                          # Pacman: Update-All-Packages
alias uld='pacman --sync --refresh'                                       # Pacman: Update-Local-Database
alias rao='pacman --remove --nosave --recursive \
           $(pacman --query --unrequired --deps --quiet) '                # Pacman: Remove-All-Orphans Packages
alias rsp='pacman --remove --recursive --nosave'                          # Pacman: Remove-Single-Package