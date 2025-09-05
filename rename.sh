#!/bin/bash

echo "Preview of renames (no changes yet):"
find . -depth -name "*.*run[0-9]*" | while read -r old; do
    dir=$(dirname "$old")
    base=$(basename "$old")

    newbase=$(echo "$base" | sed -E 's/\.run([0-9]+)/-run\1/g' | sed -E 's/\.step([0-9]+)/-step\1/g')
    new="$dir/$newbase"

    if [[ "$old" != "$new" ]]; then
        echo "$old  -->  $new"
    fi
done

echo
read -p "Proceed with renaming these files? [y/N] " confirm
if [[ "$confirm" == [yY] ]]; then
    echo "Renaming..."
    find . -depth -name "*.*run[0-9]*" | while read -r old; do
        dir=$(dirname "$old")
        base=$(basename "$old")

        newbase=$(echo "$base" | sed -E 's/\.run([0-9]+)/-run\1/g' | sed -E 's/\.step([0-9]+)/-step\1/g')
        new="$dir/$newbase"

        if [[ "$old" != "$new" ]]; then
            mv "$old" "$new"
        fi
    done
    echo "Done."
else
    echo "Aborted."
fi
