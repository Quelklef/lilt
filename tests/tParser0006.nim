
include hparser

test(
    """
    handleString: "'" $*char "'"
    """,
    newProgram(@[
        "handleString" %= ~[ ^"'", $: * @"char", ^"'" ]
    ])
)
