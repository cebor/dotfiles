for file in ~/.{exports,aliases,functions}; do
    test -e "$file" && source "$file"
done
unset file
