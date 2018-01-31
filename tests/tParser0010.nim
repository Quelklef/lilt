
include hparser

test(
    "lambTest: { <a> }",
    newProgram(@[
        "lambTest" := % <>"a"
    ])
)
