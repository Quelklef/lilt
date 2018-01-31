
include hparser

test(
    "simple: \"simple\"",
    newProgram(@[
        "simple" := ^"simple"
    ])
)
