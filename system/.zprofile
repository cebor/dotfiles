for file in ~/.dotfiles/{exports,aliases,functions,completions}; do
    test -e "$file" && source "$file"
done
unset file
