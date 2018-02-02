
include hparser

test(
    "args: &arg *[\" \" &arg]",
    newProgram(@[
        "args" %= ~[ & @"arg", * ~[ ^" ", & @"arg" ] ]
    ])
)
