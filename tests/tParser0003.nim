
include hparser

test(
    "ex: \"a\" \"b\"",
    newProgram(@[
        "ex" := ~[ ^"a" , ^"b" ]
    ])
)
