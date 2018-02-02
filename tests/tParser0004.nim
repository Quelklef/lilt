
include hparser

test(
    "ex: &e *[\"b\" &e]",
    newProgram(@[
        "ex" %= ~[ & @"e", * ~[ ^"b", & @"e" ] ]
    ])
)
