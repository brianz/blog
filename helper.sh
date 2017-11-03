new() {
    name=$1
    if [[ "$name" == "" ]]; then
        echo "Specify name of post"
        exit 1
    fi
    hugo new post/$name.md
}

new $@
