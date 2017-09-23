export PATH="$HOME/bin:$PATH"

HISTCONTROL=ignoreboth
HISTFILESIZE=1000000
HISTIGNORE='ls:bg:fg:history'
HISTSIZE=1000000
HISTTIMEFORMAT='%F %T '
PROMPT_COMMAND='history -a'
shopt -s cmdhist
shopt -s histappend
