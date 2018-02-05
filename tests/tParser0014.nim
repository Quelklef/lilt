
include hparser

test(
    "ex: | a | b | c |",
    newProgram(@[
        "ex" := |[ @"a", @"b", @"c" ]
    ])
)
