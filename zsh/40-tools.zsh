# Terraform補完
autoload -U +X bashcompinit && bashcompinit
if command -v terraform &> /dev/null; then
  complete -o nospace -C $(which terraform) terraform
fi

# pyenv初期化
if command -v pyenv &> /dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi