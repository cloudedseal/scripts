
# AUTOCOMPLETION
  
# initialize autocompletion
# autoload -U compinit && compinit
source $(brew --prefix)/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source ~/.git-bash-for-mac-zsh.sh
source /usr/local/bin/zsh-z.plugin.zsh
source "$HOME/.sdkman/bin/sdkman-init.sh"



MAVEN_HOME=~/work/maven-3.9.9
GRADLE_HOME=~/work/gradle-6.8.1

PATH=$PATH:$MAVEN_HOME/bin:$GRADLE_HOME/bin


# history setup
setopt SHARE_HISTORY
HISTFILE=$HOME/.zhistory
SAVEHIST=10000
HISTSIZE=9999
setopt HIST_EXPIRE_DUPS_FIRST

# autocompletion using arrow keys (based on history)
# bindkey '\e[A' history-search-backward
# bindkey '\e[B' history-search-forward

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# moonbit
export PATH="$HOME/.moon/bin:$PATH"
alias ll='ls -l'
. "$HOME/.local/bin/env"

# moonbit
export PATH="$HOME/.moon/bin:$PATH"

# export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 all_proxy=socks5://127.0.0.1:7897

  export NVM_DIR="$HOME/.nvm"
  [ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"  # This loads nvm


#fish
