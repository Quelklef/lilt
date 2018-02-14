
# Helper script
# Should be run before each significant `git commit`
# Included so that I stop forgetting steps in the process

code_stub="$PWD/src/lilt/private"
stable_parser_loc="$code_stub/parser_ast_stable.nim"
unstable_parser_loc="$code_stub/parser_ast.nim"
commit_sh_loc="$code_stub/commit.sh"
revert_sh_loc="$code_stub/revert.sh"

st3_stub="$PWD/st3"
st3_repo_loc="$st3_stub/Lilt.sublime-syntax"
st3_system_loc="$HOME/.config/sublime-text-3/Packages/User/Lilt.sublime-syntax"
st3_update_loc="$st3_stub/update.sh"

version_sh_loc="$PWD/version.sh"

if cmp --silent "$stable_parser_loc" "$unstable_parser_loc"; then
    echo "✔ Unstable parser matches stable parser"
else
    echo -n "Unstable parser doesn't match stable parser. Commit parser? [y/N]: "
    read reply

    if [ "$reply" == "y" ]; then
        (cd "$code_stub"; "$commit_sh_loc")
        echo "Committed parser."
    else
        echo "Took no action."
    fi
fi

if cmp --silent "$st3_repo_loc" "$st3_system_loc"; then
    echo "✔ ST3 syntax updated"
else
    echo -n "ST3 syntax not updated. Update? [y/N]: "
    read reply

    if [ "$reply" == "y" ]; then
        (cd "$st3_stub"; sh "$st3_update_loc")
        echo "Updated syntax."
    else
        echo "Took no action."
    fi
fi

echo "$( $version_sh_loc )"
echo -n "Change version? [maj/min/pat/x.y.z/N]: "
read reply
reply="${reply,,}"

if [[ "$reply" == "" || "$reply" == "N" ]]; then
    echo "Took no action."
else
    "$version_sh_loc" "$reply"
fi

echo "Now: nimble test, git status, git add, git commit"
