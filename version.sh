#!/bin/bash

# Easily update verison
# If given no arguments, prints current version
# Otherwise, expects a single argument
# If the argument is in the form x.y.z, updates the version to that version
# If the argument is "maj", "min", or "pat", will increment the major,
# minor, or patch versions respectively.

file_loc="src/version.txt"

old_ver="$( cat $file_loc )"

if [ "$#" -eq "0" ]; then
    echo "Current version: $old_ver"
    exit
fi

maj="$( echo $old_ver | cut -d "." -f 1 )"
min="$( echo $old_ver | cut -d "." -f 2 )"
pat="$( echo $old_ver | cut -d "." -f 3 )"

incremented="false"

if [ "$1" = "maj" ]; then
    maj="$(( maj + 1 ))"
    min="0"
    pat="0"
    incremented="true"
elif [ "$1" = "min" ]; then
    min="$(( min + 1 ))"
    pat="0"
    incremented="true"
elif [ "$1" = "pat" ]; then
    pat="$(( pat + 1 ))"
    incremented="true"
fi

if [ "$incremented" = "true" ]; then
    new_ver="$maj.$min.$pat"
else
    # Set new version to given version
    # First, ensure that it's a valid version
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        new_ver="$1"
    else
        echo "Invalid argument \"$1\". Expects 'maj', 'min', 'pat', or x.y.z"
        exit
    fi
fi

echo "Updated from $old_ver to $new_ver."
echo -n $new_ver > $file_loc
