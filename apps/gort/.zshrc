export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="powerlevel10k/powerlevel10k"

ZSH_DISABLE_COMPFIX="true"

plugins=(
  git
  zsh-autosuggestions
  yarn
  web-search
  jsontools
  macports
  node
  sudo
  docker
)

source $ZSH/oh-my-zsh.sh

cat motd

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(host dir rbenv)

POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

POWERLEVEL9K_PROMPT_ON_NEWLINE=false

POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=''

POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='red'

POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

echo -e "\033]6;1;bg;red;brightness;18\a"
echo -e "\033]6;1;bg;green;brightness;26\a"
echo -e "\033]6;1;bg;blue;brightness;33\a"